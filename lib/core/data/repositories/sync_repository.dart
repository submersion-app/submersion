import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Sync status for individual records
enum SyncStatus { synced, pending, conflict }

/// Cloud provider types
enum CloudProviderType { icloud, googledrive }

/// Repository for managing sync metadata and tracking
class SyncRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SyncRepository);

  static const String _globalMetadataId = 'global';

  // ============================================================================
  // Sync Metadata Operations
  // ============================================================================

  /// Get the global sync metadata (creates if not exists)
  Future<SyncMetadataData> getOrCreateMetadata() async {
    try {
      final query = _db.select(_db.syncMetadata)
        ..where((t) => t.id.equals(_globalMetadataId));

      SyncMetadataData? existing;
      try {
        existing = await query.getSingleOrNull();
      } catch (e, stackTrace) {
        _log.warning('Sync metadata read failed, attempting repair', e, stackTrace);
        await _repairSyncMetadataRow();
        existing = await query.getSingleOrNull();
      }
      if (existing != null) return existing;

      // Create new metadata with a unique device ID
      final now = DateTime.now().millisecondsSinceEpoch;
      final deviceId = _uuid.v4();

      await _db
          .into(_db.syncMetadata)
          .insert(
            SyncMetadataCompanion(
              id: const Value(_globalMetadataId),
              deviceId: Value(deviceId),
              syncVersion: const Value(1),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      _log.info('Created sync metadata with deviceId: $deviceId');

      return (await query.getSingle());
    } catch (e, stackTrace) {
      _log.error('Failed to get or create sync metadata', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _repairSyncMetadataRow() async {
    final rows = await _db.customSelect(
      '''
      SELECT id, device_id, sync_version, created_at, updated_at
      FROM sync_metadata
      WHERE id = ?
      ''',
      variables: [Variable.withString(_globalMetadataId)],
    ).get();

    if (rows.isEmpty) return;

    final row = rows.first.data;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rawDeviceId = row['device_id'];
    final rawSyncVersion = row['sync_version'];
    final rawCreatedAt = row['created_at'];
    final rawUpdatedAt = row['updated_at'];

    final needsRepair =
        rawDeviceId == null ||
        rawDeviceId is! String ||
        (rawDeviceId as String).isEmpty ||
        rawSyncVersion == null ||
        rawSyncVersion is! int ||
        rawCreatedAt == null ||
        rawCreatedAt is! int ||
        rawUpdatedAt == null ||
        rawUpdatedAt is! int;

    if (!needsRepair) return;

    final deviceId =
        rawDeviceId is String && rawDeviceId.isNotEmpty ? rawDeviceId : _uuid.v4();
    final syncVersion = rawSyncVersion is int ? rawSyncVersion : 1;
    final createdAt = rawCreatedAt is int ? rawCreatedAt : now;
    final updatedAt = rawUpdatedAt is int ? rawUpdatedAt : now;

    await _db.customStatement(
      '''
      UPDATE sync_metadata
      SET device_id = ?, sync_version = ?, created_at = ?, updated_at = ?
      WHERE id = ?
      ''',
      [deviceId, syncVersion, createdAt, updatedAt, _globalMetadataId],
    );
  }

  /// Get the device ID for this installation
  Future<String> getDeviceId() async {
    final metadata = await getOrCreateMetadata();
    return metadata.deviceId;
  }

  /// Get the last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final metadata = await getOrCreateMetadata();
    if (metadata.lastSyncTimestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(metadata.lastSyncTimestamp!);
  }

  /// Update the last sync timestamp
  Future<void> updateLastSyncTime(DateTime syncTime) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          lastSyncTimestamp: Value(syncTime.millisecondsSinceEpoch),
          updatedAt: Value(now),
        ),
      );

      _log.info('Updated last sync time to: $syncTime');
    } catch (e, stackTrace) {
      _log.error('Failed to update last sync time', e, stackTrace);
      rethrow;
    }
  }

  /// Set the cloud provider
  Future<void> setCloudProvider(CloudProviderType? provider) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          syncProvider: Value(provider?.name),
          updatedAt: Value(now),
        ),
      );

      _log.info('Set cloud provider to: ${provider?.name}');
    } catch (e, stackTrace) {
      _log.error('Failed to set cloud provider', e, stackTrace);
      rethrow;
    }
  }

  /// Get the current cloud provider
  Future<CloudProviderType?> getCloudProvider() async {
    final metadata = await getOrCreateMetadata();
    if (metadata.syncProvider == null) return null;

    return CloudProviderType.values.firstWhere(
      (e) => e.name == metadata.syncProvider,
      orElse: () => CloudProviderType.googledrive,
    );
  }

  /// Set the remote file ID for the sync file
  Future<void> setRemoteFileId(String? fileId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          remoteFileId: Value(fileId),
          updatedAt: Value(now),
        ),
      );

      _log.info('Set remote file ID');
    } catch (e, stackTrace) {
      _log.error('Failed to set remote file ID', e, stackTrace);
      rethrow;
    }
  }

  /// Get the remote file ID
  Future<String?> getRemoteFileId() async {
    final metadata = await getOrCreateMetadata();
    return metadata.remoteFileId;
  }

  // ============================================================================
  // Sync Records Operations
  // ============================================================================

  /// Mark a record as pending sync
  Future<void> markRecordPending({
    required String entityType,
    required String recordId,
    required int localUpdatedAt,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = '${entityType}_$recordId';

      await _db
          .into(_db.syncRecords)
          .insertOnConflictUpdate(
            SyncRecordsCompanion(
              id: Value(id),
              entityType: Value(entityType),
              recordId: Value(recordId),
              localUpdatedAt: Value(localUpdatedAt),
              syncStatus: const Value('pending'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark record pending: $entityType/$recordId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Mark a record as synced
  Future<void> markRecordSynced({
    required String entityType,
    required String recordId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = '${entityType}_$recordId';

      await _db
          .into(_db.syncRecords)
          .insertOnConflictUpdate(
            SyncRecordsCompanion(
              id: Value(id),
              entityType: Value(entityType),
              recordId: Value(recordId),
              localUpdatedAt: Value(now),
              syncStatus: const Value('synced'),
              syncedAt: Value(now),
              conflictData: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark record synced: $entityType/$recordId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Mark a record as having a conflict
  Future<void> markRecordConflict({
    required String entityType,
    required String recordId,
    required String conflictDataJson,
    required int localUpdatedAt,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = '${entityType}_$recordId';

      await _db
          .into(_db.syncRecords)
          .insertOnConflictUpdate(
            SyncRecordsCompanion(
              id: Value(id),
              entityType: Value(entityType),
              recordId: Value(recordId),
              localUpdatedAt: Value(localUpdatedAt),
              syncStatus: const Value('conflict'),
              conflictData: Value(conflictDataJson),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      _log.warning('Marked conflict for: $entityType/$recordId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark record conflict: $entityType/$recordId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all pending sync records
  Future<List<SyncRecord>> getPendingRecords() async {
    try {
      final query = _db.select(_db.syncRecords)
        ..where((t) => t.syncStatus.equals('pending'));
      return query.get();
    } catch (e, stackTrace) {
      _log.error('Failed to get pending records', e, stackTrace);
      rethrow;
    }
  }

  /// Get all conflict records
  Future<List<SyncRecord>> getConflictRecords() async {
    try {
      final query = _db.select(_db.syncRecords)
        ..where((t) => t.syncStatus.equals('conflict'));
      return query.get();
    } catch (e, stackTrace) {
      _log.error('Failed to get conflict records', e, stackTrace);
      rethrow;
    }
  }

  /// Get count of pending changes
  Future<int> getPendingCount() async {
    try {
      final records = await getPendingRecords();
      return records.length;
    } catch (e, stackTrace) {
      _log.error('Failed to get pending count', e, stackTrace);
      return 0;
    }
  }

  /// Clear all pending sync records
  Future<void> clearPendingRecords() async {
    try {
      await (_db.delete(
        _db.syncRecords,
      )..where((t) => t.syncStatus.equals('pending'))).go();
      _log.info('Cleared pending sync records');
    } catch (e, stackTrace) {
      _log.error('Failed to clear pending sync records', e, stackTrace);
      rethrow;
    }
  }

  /// Get count of conflicts
  Future<int> getConflictCount() async {
    try {
      final records = await getConflictRecords();
      return records.length;
    } catch (e, stackTrace) {
      _log.error('Failed to get conflict count', e, stackTrace);
      return 0;
    }
  }

  /// Clear a conflict record after resolution
  Future<void> clearConflict({
    required String entityType,
    required String recordId,
  }) async {
    try {
      final id = '${entityType}_$recordId';
      await (_db.delete(_db.syncRecords)..where((t) => t.id.equals(id))).go();
      _log.info('Cleared conflict for: $entityType/$recordId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear conflict: $entityType/$recordId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Clear all sync records (useful after full sync)
  Future<void> clearAllSyncRecords() async {
    try {
      await _db.delete(_db.syncRecords).go();
      _log.info('Cleared all sync records');
    } catch (e, stackTrace) {
      _log.error('Failed to clear all sync records', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Deletion Log Operations
  // ============================================================================

  /// Log a record deletion for sync
  Future<void> logDeletion({
    required String entityType,
    required String recordId,
    int? deletedAt,
  }) async {
    try {
      final id = _uuid.v4();
      final now = deletedAt ?? DateTime.now().millisecondsSinceEpoch;

      await _db
          .into(_db.deletionLog)
          .insert(
            DeletionLogCompanion(
              id: Value(id),
              entityType: Value(entityType),
              recordId: Value(recordId),
              deletedAt: Value(now),
            ),
          );

      _log.info('Logged deletion: $entityType/$recordId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to log deletion: $entityType/$recordId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get deletions since a given timestamp
  Future<List<DeletionLogData>> getDeletionsSince(DateTime since) async {
    try {
      final query = _db.select(_db.deletionLog)
        ..where(
          (t) => t.deletedAt.isBiggerOrEqualValue(since.millisecondsSinceEpoch),
        );
      return query.get();
    } catch (e, stackTrace) {
      _log.error('Failed to get deletions since: $since', e, stackTrace);
      rethrow;
    }
  }

  /// Get all deletions
  Future<List<DeletionLogData>> getAllDeletions() async {
    try {
      return _db.select(_db.deletionLog).get();
    } catch (e, stackTrace) {
      _log.error('Failed to get all deletions', e, stackTrace);
      rethrow;
    }
  }

  /// Log a deletion if one doesn't already exist for the same record
  Future<void> logDeletionIfMissing({
    required String entityType,
    required String recordId,
    required int deletedAt,
  }) async {
    final existing =
        await (_db.select(_db.deletionLog)
              ..where((t) => t.entityType.equals(entityType))
              ..where((t) => t.recordId.equals(recordId)))
            .getSingleOrNull();
    if (existing != null) return;
    await logDeletion(
      entityType: entityType,
      recordId: recordId,
      deletedAt: deletedAt,
    );
  }

  /// Clear old deletions (older than given days)
  Future<void> clearOldDeletions({int olderThanDays = 90}) async {
    try {
      final cutoff = DateTime.now()
          .subtract(Duration(days: olderThanDays))
          .millisecondsSinceEpoch;

      await (_db.delete(
        _db.deletionLog,
      )..where((t) => t.deletedAt.isSmallerThanValue(cutoff))).go();

      _log.info('Cleared deletions older than $olderThanDays days');
    } catch (e, stackTrace) {
      _log.error('Failed to clear old deletions', e, stackTrace);
      rethrow;
    }
  }

  /// Clear all deletions (after successful sync)
  Future<void> clearAllDeletions() async {
    try {
      await _db.delete(_db.deletionLog).go();
      _log.info('Cleared all deletions');
    } catch (e, stackTrace) {
      _log.error('Failed to clear all deletions', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Utility Methods
  // ============================================================================

  /// Check if sync is enabled (has a provider set)
  Future<bool> isSyncEnabled() async {
    final provider = await getCloudProvider();
    return provider != null;
  }

  /// Check if there are any pending changes or conflicts
  Future<bool> hasUnsyncedChanges() async {
    final pendingCount = await getPendingCount();
    final conflictCount = await getConflictCount();
    final deletions = await getAllDeletions();
    return pendingCount > 0 || conflictCount > 0 || deletions.isNotEmpty;
  }

  /// Reset sync state (useful for testing or switching accounts)
  Future<void> resetSyncState() async {
    try {
      await clearAllSyncRecords();
      await clearAllDeletions();

      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          lastSyncTimestamp: const Value(null),
          remoteFileId: const Value(null),
          updatedAt: Value(now),
        ),
      );

      _log.info('Reset sync state');
    } catch (e, stackTrace) {
      _log.error('Failed to reset sync state', e, stackTrace);
      rethrow;
    }
  }
}
