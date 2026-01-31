import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/maps/domain/entities/cached_region.dart'
    as domain;
import 'package:uuid/uuid.dart';

/// Repository for managing cached map regions.
class OfflineMapRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  OfflineMapRepository(this._db);

  /// Get all cached regions.
  Future<List<domain.CachedRegion>> getAllRegions() async {
    final rows = await _db.select(_db.cachedRegions).get();
    return rows.map(_rowToEntity).toList();
  }

  /// Get a cached region by ID.
  Future<domain.CachedRegion?> getRegionById(String id) async {
    final row = await (_db.select(
      _db.cachedRegions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row != null ? _rowToEntity(row) : null;
  }

  /// Create a new cached region record.
  Future<domain.CachedRegion> createRegion({
    required String name,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int minZoom,
    required int maxZoom,
    required int tileCount,
    required int sizeBytes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();

    await _db
        .into(_db.cachedRegions)
        .insert(
          CachedRegionsCompanion.insert(
            id: id,
            name: name,
            minLat: minLat,
            maxLat: maxLat,
            minLng: minLng,
            maxLng: maxLng,
            minZoom: minZoom,
            maxZoom: maxZoom,
            tileCount: tileCount,
            sizeBytes: sizeBytes,
            createdAt: now,
            lastAccessedAt: now,
          ),
        );

    return domain.CachedRegion(
      id: id,
      name: name,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      minZoom: minZoom,
      maxZoom: maxZoom,
      tileCount: tileCount,
      sizeBytes: sizeBytes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  /// Update a cached region (e.g., after re-download or size change).
  Future<void> updateRegion(domain.CachedRegion region) async {
    await (_db.update(
      _db.cachedRegions,
    )..where((t) => t.id.equals(region.id))).write(
      CachedRegionsCompanion(
        name: Value(region.name),
        tileCount: Value(region.tileCount),
        sizeBytes: Value(region.sizeBytes),
        lastAccessedAt: Value(region.lastAccessedAt.millisecondsSinceEpoch),
      ),
    );
  }

  /// Update last accessed timestamp.
  Future<void> touchRegion(String id) async {
    await (_db.update(_db.cachedRegions)..where((t) => t.id.equals(id))).write(
      CachedRegionsCompanion(
        lastAccessedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Delete a cached region record.
  Future<void> deleteRegion(String id) async {
    await (_db.delete(_db.cachedRegions)..where((t) => t.id.equals(id))).go();
  }

  /// Get total size of all cached regions.
  Future<int> getTotalSize() async {
    final regions = await getAllRegions();
    return regions.fold<int>(0, (sum, r) => sum + r.sizeBytes);
  }

  domain.CachedRegion _rowToEntity(CachedRegion row) {
    return domain.CachedRegion(
      id: row.id,
      name: row.name,
      minLat: row.minLat,
      maxLat: row.maxLat,
      minLng: row.minLng,
      maxLng: row.maxLng,
      minZoom: row.minZoom,
      maxZoom: row.maxZoom,
      tileCount: row.tileCount,
      sizeBytes: row.sizeBytes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(row.lastAccessedAt),
    );
  }
}
