import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_lake_levels.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

const _log = LoggerService('BathymetryRepository');

/// Cache-first bathymetry access. Grids cache per quantized 0.02 degree
/// coordinate cell (nearby sites, re-pinned sites, and site-less GPS dives
/// share one fetch) -- EXCEPT inside a swissBATHY3D lake, where that cell
/// (~2.2 km x 1.5 km at Swiss latitudes) is coarser than the 1 km tiles the
/// source actually serves, so two real dive sites in the same cell but
/// different tiles would wrongly share one grid. There, [quantumDegFor]
/// returns 0 and the raw coordinate is used as-is: no false coalescing,
/// while [SwissBathyTileCacheRepository] still dedupes the actual tile
/// downloads (see swissbathy3d_source.dart), so this never multiplies
/// network requests. Definitive negatives cache as 'empty'; transient
/// failures write NO row so the next visit retries. Never throws: null
/// simply means "no real terrain available right now".
///
/// Known trade-off, deliberately deferred to issue #1511: keying Swiss
/// coordinates raw also gives up the outer cache's coalescing for them, so
/// two points a few metres apart (a re-pinned site, a site-less GPS dive)
/// each pay their own resolve and stitch even though they land on the same
/// 1 km tiles. That cost is CPU, not network, because the tile downloads
/// underneath are still deduped. Keying by LV95 tile (or by the tile range
/// the span covers) would buy the coalescing back without reintroducing the
/// false sharing this branch exists to prevent, but it belongs with the
/// pre-processed-data work in #1511 rather than in the correctness fixes
/// here: that issue may replace the live STAC fetch outright, which would
/// change what the right key even is.
class BathymetryRepository {
  static const int maxGridDim = 120;

  /// Bumped whenever source SELECTION changes, not just the span. Cached
  /// rows never expire, so without this every already-visited site would
  /// keep serving the grid its old resolver chose. Old rows go inert, the
  /// same way the 4 km rows did when the span went to 8 km.
  ///
  /// v3: the swissBATHY3D lake whitelist changed (Greifensee/Lago di
  /// Lugano/Pfäffikersee removed, Lac de Joux/Lungernsee/Silsersee/
  /// Silvaplanersee/Rotsee added) -- without bumping this, a coordinate at
  /// one of the five newly-covered lakes that had already cached a
  /// fallback grid from a coarser regional/global source would keep
  /// serving that stale grid forever instead of re-resolving through
  /// swissBATHY3D now that it covers it (Copilot review).
  ///
  /// v4 (#1763, already merged): forces a fresh outer read for an install
  /// that already visited this v3 whitelist fix, so it also reaches
  /// #1763's inner swiss_bathy_tile_cache reference-level fix instead of
  /// the outer cache masking it forever.
  ///
  /// v5 here: this branch's own cross-lake fix (resolving each tile's
  /// lake independently instead of the fetch center's lake for all of
  /// them) changes what some ALREADY-v4-cached Rotsee/Vierwaldstättersee-
  /// area coordinates should have resolved to, so those rows need one
  /// more forced re-resolution too.
  static const String selectionGeneration = 'v5';
  static const double quantumDeg = 0.02;

  final LocalCacheDatabase _db;
  final BathymetryResolver _resolver;
  final Map<String, Future<BathymetryGrid?>> _inFlight = {};

  BathymetryRepository({
    required LocalCacheDatabase db,
    required BathymetryResolver resolver,
  }) : _db = db,
       _resolver = resolver;

  /// The cache granularity that applies to [c]: 0 (no quantization, use the
  /// raw coordinate) inside a swissBATHY3D lake, [quantumDeg] everywhere
  /// else. Mirrors [SwissBathy3dSource.covers] -- the same "is this lake
  /// coverage" check the resolver itself uses to pick that source -- so
  /// this stays in lockstep even though it runs ahead of the resolver, at
  /// every call site that builds a cache/provider key from a raw
  /// coordinate.
  static double quantumDegFor(GeoPoint c) =>
      findSwissLake(c) != null ? 0 : quantumDeg;

  static ({double lat, double lon}) quantize(GeoPoint c) {
    final quantum = quantumDegFor(c);
    if (quantum <= 0) return (lat: c.latitude, lon: c.longitude);
    double q(double v) => (v / quantum).floorToDouble() * quantum;
    return (lat: q(c.latitude), lon: q(c.longitude));
  }

  static String keyFor(GeoPoint c) {
    // The span AND the selection generation are part of the key: cached
    // rows never expire, so any change that would resolve a coordinate
    // differently must miss the old rows and refetch. Stale rows are inert
    // leftovers in this local-only cache.
    final span = BathymetryResolver.defaultSpanMeters.round();
    final lake = findSwissLake(c);
    if (lake != null) {
      // The lake's OWN mean level rides along in the key, not just
      // selectionGeneration: _load returns a matching outer row before the
      // resolver -- and so before SwissBathyTileCacheRepository.read's own
      // reference-level check -- ever runs again, so a FUTURE correction
      // to this lake's documented level (independent of any code change,
      // and so not covered by any one-time generation bump) would
      // otherwise keep serving the outer cache's stale depths forever
      // (Copilot review). Folding the level in here means only the
      // coordinates of the ACTUALLY corrected lake miss, not the whole
      // cache, and needs no manual bump at all going forward.
      //
      // Raw coordinate, not a quantized cell corner: needs enough decimals
      // to actually distinguish nearby sites (2 decimals is ~1 km at these
      // latitudes -- exactly the coalescing this branch exists to avoid).
      // See the class doc for the cache-coalescing this gives up, and why
      // that is deferred to issue #1511.
      return '${c.latitude.toStringAsFixed(6)},'
          '${c.longitude.toStringAsFixed(6)}@$span$selectionGeneration'
          '@${lake.meanLevelMeters}';
    }
    final q = quantize(c);
    return '${q.lat.toStringAsFixed(2)},${q.lon.toStringAsFixed(2)}'
        '@$span$selectionGeneration';
  }

  /// Whether the cache holds a DEFINITIVE answer (grid or empty) for this
  /// coordinate's cell. False means a null from [getGrid] was transient
  /// (network failure, broken cache) and worth retrying later.
  Future<bool> hasCachedAnswer(GeoPoint center) async {
    try {
      final row = await (_db.select(
        _db.bathymetryCache,
      )..where((t) => t.cacheKey.equals(keyFor(center)))).getSingleOrNull();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<BathymetryGrid?> getGrid(GeoPoint center) {
    final key = keyFor(center);
    return _inFlight[key] ??= _guardedLoad(key, center)
      ..whenComplete(() => _inFlight.remove(key));
  }

  /// The scene must survive ANY cache/fetch failure (a broken table, an
  /// unexpected parser error) by degrading to synthesized terrain — so
  /// every failure becomes a null grid, treated as transient (no caching).
  ///
  /// Logged via [LoggerService] rather than a debug-only `assert`/`print` —
  /// the previous debug-only logging meant a release build (including a
  /// TestFlight/Play Store beta) had no way to tell "no data because
  /// nothing covers this coordinate" apart from "swissBATHY3D itself is
  /// failing for a diagnosable reason", both of which render identically as
  /// "keine Daten verfügbar" in the UI.
  ///
  /// [LoggerService]'s persistent file backend and the in-app debug log
  /// viewer are still gated behind the user's own "Debug-Modus" setting
  /// (see `main.dart`), on purpose — bathymetry log lines embed GPS
  /// coordinates, so writing them to disk for every install by default
  /// would be a real privacy cost most users never asked for (Copilot
  /// review). The fix here is still a genuine improvement over the old
  /// `assert`: it no longer requires a DEBUG BUILD, which a real user's
  /// installed release/beta app can never be — only that the user (or a
  /// support conversation walking them through it) flips Debug-Modus on in
  /// Settings before reproducing, in any build.
  Future<BathymetryGrid?> _guardedLoad(String key, GeoPoint center) async {
    try {
      return await _load(key, center);
    } catch (e, stackTrace) {
      _log.warning(
        'getGrid($key) degraded to null',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<BathymetryGrid?> _load(String key, GeoPoint center) async {
    final row = await (_db.select(
      _db.bathymetryCache,
    )..where((t) => t.cacheKey.equals(key))).getSingleOrNull();
    if (row != null) {
      if (row.status != 'ok') {
        return null; // 'empty' / 'unavailable': definitive, no refetch
      }
      final json = row.gridJson;
      if (json != null) {
        try {
          return BathymetryGrid.fromJson(
            jsonDecode(json) as Map<String, dynamic>,
          );
        } catch (_) {
          // Fall through to the corruption handling below.
        }
      }
      // An 'ok' row without a decodable grid is corruption: left in place
      // it would wedge this cell on synthesized terrain forever AND read
      // as a definitive answer to the retry logic. Drop it and fall
      // through to a fresh resolve.
      await (_db.delete(
        _db.bathymetryCache,
      )..where((t) => t.cacheKey.equals(key))).go();
    }

    // Fetch centered on the quantized CELL CENTER so every coordinate in
    // the cell gets the same, fully covering grid -- except where
    // [quantumDegFor] opts out of quantization (swissBATHY3D lakes), where
    // the raw coordinate itself IS the fetch center: no cell to center on.
    final quantum = quantumDegFor(center);
    final q = quantize(center);
    final fetchCenter = quantum > 0
        ? GeoPoint(q.lat + quantum / 2, q.lon + quantum / 2)
        : center;
    final res = await _resolver.resolve(fetchCenter);
    final resolved = res.grid;
    if (resolved != null) {
      final grid = resolved.downsampleTo(maxGridDim);
      await _db
          .into(_db.bathymetryCache)
          .insertOnConflictUpdate(
            BathymetryCacheCompanion.insert(
              cacheKey: key,
              centerLat: fetchCenter.latitude,
              centerLon: fetchCenter.longitude,
              status: 'ok',
              sourceId: Value(grid.sourceId),
              resolutionMeters: Value(grid.resolutionMeters),
              gridJson: Value(jsonEncode(grid.toJson())),
              fetchedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      return grid;
    }
    if (res.definitive) {
      await _db
          .into(_db.bathymetryCache)
          .insertOnConflictUpdate(
            BathymetryCacheCompanion.insert(
              cacheKey: key,
              centerLat: fetchCenter.latitude,
              centerLon: fetchCenter.longitude,
              status: 'empty',
              fetchedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    }
    return null; // transient: no row, next call retries
  }
}
