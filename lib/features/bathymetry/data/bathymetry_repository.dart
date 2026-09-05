import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_lake_levels.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

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
class BathymetryRepository {
  static const int maxGridDim = 120;
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
    // The span is part of the key: cached rows never expire, so a span
    // change must miss the old rows and refetch the larger area. Stale
    // rows are inert leftovers in this local-only cache.
    final span = BathymetryResolver.defaultSpanMeters.round();
    if (quantumDegFor(c) <= 0) {
      // Raw coordinate, not a quantized cell corner: needs enough decimals
      // to actually distinguish nearby sites (2 decimals is ~1 km at these
      // latitudes -- exactly the coalescing this branch exists to avoid).
      return '${c.latitude.toStringAsFixed(6)},'
          '${c.longitude.toStringAsFixed(6)}@$span';
    }
    final q = quantize(c);
    return '${q.lat.toStringAsFixed(2)},${q.lon.toStringAsFixed(2)}@$span';
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
  Future<BathymetryGrid?> _guardedLoad(String key, GeoPoint center) async {
    try {
      return await _load(key, center);
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('BathymetryRepository.getGrid($key) degraded to null: $e');
        return true;
      }());
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
