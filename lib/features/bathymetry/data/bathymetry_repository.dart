import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Cache-first bathymetry access. Grids cache per quantized 0.02 degree
/// coordinate cell (nearby sites, re-pinned sites, and site-less GPS dives
/// share one fetch). Definitive negatives cache as 'empty'; transient
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

  static ({double lat, double lon}) quantize(GeoPoint c) {
    double q(double v) => (v / quantumDeg).floorToDouble() * quantumDeg;
    return (lat: q(c.latitude), lon: q(c.longitude));
  }

  static String keyFor(GeoPoint c) {
    final q = quantize(c);
    // The span is part of the key: cached rows never expire, so a span
    // change must miss the old rows and refetch the larger area. Stale
    // rows are inert leftovers in this local-only cache.
    final span = BathymetryResolver.defaultSpanMeters.round();
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
    // the cell gets the same, fully covering grid.
    final q = quantize(center);
    final fetchCenter = GeoPoint(
      q.lat + quantumDeg / 2,
      q.lon + quantumDeg / 2,
    );
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
