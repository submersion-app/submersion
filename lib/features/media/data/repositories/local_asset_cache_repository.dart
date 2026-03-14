import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';

/// Cache entry with all fields for inspection.
class CacheEntry {
  final String mediaId;
  final String? localAssetId;
  final int resolvedAt;
  final String resolutionMethod;
  final int attemptCount;

  const CacheEntry({
    required this.mediaId,
    this.localAssetId,
    required this.resolvedAt,
    required this.resolutionMethod,
    required this.attemptCount,
  });
}

/// Repository for the local asset resolution cache.
///
/// Provides CRUD operations on the local_asset_cache table.
/// This table is device-local and never synced.
class LocalAssetCacheRepository {
  LocalCacheDatabase get _db => LocalCacheDatabaseService.instance.database;

  /// Escalating backoff intervals for unresolved entries.
  static const _backoffDurations = [
    Duration(hours: 24),
    Duration(days: 3),
    Duration(days: 7),
  ];

  /// Get the cached local asset ID for a media item.
  /// Returns null if no cache entry exists.
  Future<String?> getCachedAssetId(String mediaId) async {
    final row = await (_db.select(
      _db.localAssetCache,
    )..where((t) => t.mediaId.equals(mediaId))).getSingleOrNull();
    return row?.localAssetId;
  }

  /// Get the full cache entry for inspection/testing.
  Future<CacheEntry?> getCacheEntry(String mediaId) async {
    final row = await (_db.select(
      _db.localAssetCache,
    )..where((t) => t.mediaId.equals(mediaId))).getSingleOrNull();
    if (row == null) return null;

    return CacheEntry(
      mediaId: row.mediaId,
      localAssetId: row.localAssetId,
      resolvedAt: row.resolvedAt,
      resolutionMethod: row.resolutionMethod,
      attemptCount: row.attemptCount,
    );
  }

  /// Cache a resolution result (resolved or unresolved).
  Future<void> cacheResolution({
    required String mediaId,
    required String? localAssetId,
    required String method,
  }) async {
    await _db
        .into(_db.localAssetCache)
        .insertOnConflictUpdate(
          LocalAssetCacheCompanion.insert(
            mediaId: mediaId,
            localAssetId: Value(localAssetId),
            resolvedAt: DateTime.now().millisecondsSinceEpoch,
            resolutionMethod: method,
            attemptCount: const Value(0),
          ),
        );
  }

  /// Remove a cached entry (e.g., when re-resolution is needed).
  Future<void> clearEntry(String mediaId) async {
    await (_db.delete(
      _db.localAssetCache,
    )..where((t) => t.mediaId.equals(mediaId))).go();
  }

  /// Check if an unresolved entry has exceeded its backoff period.
  /// Returns false for resolved entries (they never expire).
  Future<bool> isExpired(String mediaId) async {
    final entry = await getCacheEntry(mediaId);
    if (entry == null) return true;
    if (entry.localAssetId != null) return false;

    final backoffIndex = entry.attemptCount.clamp(
      0,
      _backoffDurations.length - 1,
    );
    final backoff = _backoffDurations[backoffIndex];
    final resolvedAt = DateTime.fromMillisecondsSinceEpoch(entry.resolvedAt);

    return DateTime.now().isAfter(resolvedAt.add(backoff));
  }

  /// Increment the attempt count for an unresolved entry.
  Future<void> incrementAttempt(String mediaId) async {
    final entry = await getCacheEntry(mediaId);
    if (entry == null) return;

    await (_db.update(
      _db.localAssetCache,
    )..where((t) => t.mediaId.equals(mediaId))).write(
      LocalAssetCacheCompanion(
        attemptCount: Value(entry.attemptCount + 1),
        resolvedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
