import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/geo_math.dart';
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

  /// Whether [spanMeters] asks for a narrower-than-base-square LOD patch
  /// (the `medium`/`fine` stages in `bathymetry_lod.dart`), as opposed to
  /// the always-loaded 8 km base square. A patch is requested for one
  /// specific site's zoomed-in view, so it must resolve at the site's EXACT
  /// coordinate: the quantized 0.02 degree cell center used for the base
  /// square can sit ~1.1-1.5 km away, which dwarfs a patch's own half-width
  /// (e.g. 250 m for `fine`) and can point the patch nowhere near the real
  /// site.
  static bool _isPatchSpan(double? spanMeters) =>
      spanMeters != null && spanMeters < BathymetryResolver.defaultSpanMeters;

  static String keyFor(GeoPoint c, {double? spanMeters}) {
    // The span AND the selection generation are part of the key: cached
    // rows never expire, so any change that would resolve a coordinate
    // differently must miss the old rows and refetch. Stale rows are inert
    // leftovers in this local-only cache.
    //
    // Defaulting to [BathymetryResolver.defaultSpanMeters] when [spanMeters]
    // is omitted keeps every existing base-square cache key byte-for-byte
    // unchanged; only an explicit (smaller) LOD-patch span produces a
    // different, additional key.
    final span = (spanMeters ?? BathymetryResolver.defaultSpanMeters).round();
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
    if (_isPatchSpan(spanMeters)) {
      // Same reasoning as the lake branch above, for a different reason: a
      // patch is resolved at the exact site coordinate (see _isPatchSpan),
      // so two real sites a few hundred metres apart -- well within one
      // quantized cell -- must not collide on the same cache row.
      return '${c.latitude.toStringAsFixed(6)},'
          '${c.longitude.toStringAsFixed(6)}@$span$selectionGeneration';
    }
    final q = quantize(c);
    return '${q.lat.toStringAsFixed(2)},${q.lon.toStringAsFixed(2)}'
        '@$span$selectionGeneration';
  }

  /// Whether the cache holds a DEFINITIVE answer (grid or empty) for this
  /// coordinate's cell (or, with [spanMeters], for its LOD patch cell --
  /// see [getGridForSpan]). False means a null from [getGrid]/
  /// [getGridForSpan] was transient (network failure, broken cache) and
  /// worth retrying later.
  Future<bool> hasCachedAnswer(GeoPoint center, {double? spanMeters}) async {
    try {
      final row =
          await (_db.select(_db.bathymetryCache)..where(
                (t) =>
                    t.cacheKey.equals(keyFor(center, spanMeters: spanMeters)),
              ))
              .getSingleOrNull();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<BathymetryGrid?> getGrid(GeoPoint center) {
    final key = keyFor(center);
    return _inFlight[key] ??= _guardedLoad(
      key,
      center,
      BathymetryResolver.defaultSpanMeters,
      maxGridDim,
    )..whenComplete(() => _inFlight.remove(key));
  }

  /// A smaller, additional LOD patch grid around [center] -- e.g. the
  /// `medium`/`fine`/`superFine` stages in `bathymetry_lod.dart` -- fetched
  /// and cached independently of the always-loaded [defaultSpanMeters] base
  /// square. Shares every cache/dedup/quantization rule with [getGrid]; the
  /// span (and so the cache key) differs, and [maxDim] lets a stage ask for
  /// a finer downsample cap than the base square's (see
  /// [BathymetryLodStage.maxGridDim]'s doc) -- defaults to this
  /// repository's own [maxGridDim] when omitted. Not folded into the cache
  /// key: every stage that calls this today has its own, unique span, so
  /// [spanMeters] alone already disambiguates the row.
  Future<BathymetryGrid?> getGridForSpan(
    GeoPoint center,
    double spanMeters, {
    int? maxDim,
  }) {
    final key = keyFor(center, spanMeters: spanMeters);
    return _inFlight[key] ??= _guardedLoad(
      key,
      center,
      spanMeters,
      maxDim ?? maxGridDim,
    )..whenComplete(() => _inFlight.remove(key));
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
  Future<BathymetryGrid?> _guardedLoad(
    String key,
    GeoPoint center,
    double spanMeters,
    int maxDim,
  ) async {
    try {
      return await _load(key, center, spanMeters, maxDim);
    } catch (e, stackTrace) {
      _log.warning(
        'getGrid($key) degraded to null',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<BathymetryGrid?> _load(
    String key,
    GeoPoint center,
    double spanMeters,
    int maxDim,
  ) async {
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
    // [quantumDegFor] opts out of quantization (swissBATHY3D lakes), or
    // where [spanMeters] asks for a narrower-than-base-square LOD patch
    // (see [_isPatchSpan]): in both cases the raw coordinate itself IS the
    // fetch center, no cell to center on. A patch's own half-width is often
    // smaller than the quantized cell's offset from the real coordinate, so
    // snapping it to the cell center could point the patch nowhere near the
    // actual site.
    final quantum = _isPatchSpan(spanMeters) ? 0.0 : quantumDegFor(center);
    final q = quantize(center);
    final fetchCenter = quantum > 0
        ? GeoPoint(q.lat + quantum / 2, q.lon + quantum / 2)
        : center;
    final res = await _resolver.resolve(fetchCenter, spanMeters: spanMeters);
    final resolved = res.grid;
    if (resolved != null) {
      final grid = _cropToSpan(
        resolved,
        fetchCenter,
        spanMeters,
      ).downsampleTo(maxDim);
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

  /// A `BathymetrySource.fetch` implementation is trusted to honor the
  /// requested span -- and every shipped source does, except
  /// `EtopoErddapSource` (etopo_erddap_source.dart), which floors its own
  /// request box at 10 km regardless of how narrow a caller's span actually
  /// is (see the comment on its `fetch`). The grid that comes back is still
  /// correctly geo-referenced, real data per cell, not corrupted -- but for
  /// a small LOD patch it can be many times wider than the patch's own
  /// intended footprint, stretching the rendered patch far past where the
  /// diver zoomed in.
  ///
  /// Crops back to (approximately) the requested box around [center]
  /// whenever [grid] materially overshoots [spanMeters] in either
  /// dimension; a source that already matches -- everyone but ETOPO -- is
  /// returned untouched, with a tolerance so a near-exact match is never
  /// trimmed over floating-point rounding.
  static BathymetryGrid _cropToSpan(
    BathymetryGrid grid,
    GeoPoint center,
    double spanMeters,
  ) {
    const overshootTolerance = 1.1;
    final mLon = metersPerDegreeLongitude(center.latitude);
    final actualLatSpan =
        (grid.rows - 1) * grid.cellSizeLatDeg.abs() * metersPerDegreeLatitude;
    final actualLonSpan = (grid.cols - 1) * grid.cellSizeLonDeg.abs() * mLon;
    if (actualLatSpan <= spanMeters * overshootTolerance &&
        actualLonSpan <= spanMeters * overshootTolerance) {
      return grid;
    }

    final half = spanMeters / 2;
    final dLat = half / metersPerDegreeLatitude;
    final dLon = half / mLon;

    int rowAt(double lat) => ((lat - grid.originLat) / grid.cellSizeLatDeg)
        .round()
        .clamp(0, grid.rows - 1);
    int colAt(double lon) => ((lon - grid.originLon) / grid.cellSizeLonDeg)
        .round()
        .clamp(0, grid.cols - 1);

    final rStart = rowAt(center.latitude - dLat);
    final rEnd = rowAt(center.latitude + dLat);
    final cStart = colAt(center.longitude - dLon);
    final cEnd = colAt(center.longitude + dLon);
    if (rEnd <= rStart || cEnd <= cStart) {
      // Degenerate crop (spanMeters narrower than one of the source's own
      // cells): keep the original grid rather than hand back a sliver.
      return grid;
    }

    final newRows = rEnd - rStart + 1;
    final newCols = cEnd - cStart + 1;
    final out = List<double?>.filled(newRows * newCols, null);
    for (var r = 0; r < newRows; r++) {
      for (var c = 0; c < newCols; c++) {
        out[r * newCols + c] = grid.depthAt(r + rStart, c + cStart);
      }
    }
    return BathymetryGrid(
      originLat: grid.originLat + grid.cellSizeLatDeg * rStart,
      originLon: grid.originLon + grid.cellSizeLonDeg * cStart,
      cellSizeLatDeg: grid.cellSizeLatDeg,
      cellSizeLonDeg: grid.cellSizeLonDeg,
      rows: newRows,
      cols: newCols,
      depthsMeters: out,
      sourceId: grid.sourceId,
      resolutionMeters: grid.resolutionMeters,
      fetchedAt: grid.fetchedAt,
    );
  }

  /// Deletes every cached row whose winning source was [sourceId]. Used by
  /// the "3D Maps" settings page's swissBATHY3D delete action, alongside
  /// clearing that tile's own rows in [SwissBathyTileCache] -- deleting only
  /// one of the two tables has no visible effect, since the other keeps
  /// serving its already-resolved answer.
  Future<void> clearBySource(String sourceId) async {
    await (_db.delete(
      _db.bathymetryCache,
    )..where((t) => t.sourceId.equals(sourceId))).go();
  }

  /// Average byte size of a cached 'ok' grid's JSON across every provider,
  /// or null when there are no 'ok' rows to average from (e.g. right after a
  /// reset). Used only for the "3D Maps" reload confirmation dialog's
  /// approximate size estimate -- computed BEFORE any deletion, since the
  /// estimate would otherwise have nothing left to average from.
  Future<int?> averageCachedGridBytes() async {
    final rows = await (_db.select(
      _db.bathymetryCache,
    )..where((t) => t.status.equals('ok') & t.gridJson.isNotNull())).get();
    if (rows.isEmpty) return null;
    final total = rows.fold<int>(
      0,
      (sum, r) => sum + utf8.encode(r.gridJson!).length,
    );
    return total ~/ rows.length;
  }

  /// Deletes every cached row NOT attributed to [sourceId] -- including rows
  /// with no `sourceId` at all (a definitive "no water here" negative from a
  /// GLOBAL source, see the 'empty' branch above, which is never attributed
  /// to any one source). Without including those, a negative cached before
  /// [sourceId] started covering that coordinate (e.g. a swissBATHY3D lake
  /// whitelist addition) would stay permanently unreachable by either this
  /// or [clearBySource].
  Future<void> clearAllExceptSource(String sourceId) async {
    await (_db.delete(_db.bathymetryCache)..where(
          (t) => t.sourceId.isNull() | t.sourceId.equals(sourceId).not(),
        ))
        .go();
  }
}
