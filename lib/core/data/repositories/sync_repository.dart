import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';

/// Sync status for individual records
enum SyncStatus { synced, pending, conflict }

/// Cloud provider types
enum CloudProviderType { icloud, googledrive, s3 }

/// Repository for managing sync metadata and tracking
class SyncRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SyncRepository);

  static const String _globalMetadataId = 'global';

  /// Conflict-capable syncable entities that carry an `hlc` column, mapped to
  /// their SQLite table name and primary-key column. markRecordPending stamps
  /// a fresh Hybrid Logical Clock onto these rows so cross-device merges can
  /// order edits correctly under wall-clock skew. Entities not listed here
  /// (append-only tables) fall back to updatedAt ordering.
  static const Map<String, ({String table, String pk})> _hlcTargets = {
    'divers': (table: 'divers', pk: 'id'),
    'diverSettings': (table: 'diver_settings', pk: 'id'),
    'buddies': (table: 'buddies', pk: 'id'),
    'diveCenters': (table: 'dive_centers', pk: 'id'),
    'trips': (table: 'trips', pk: 'id'),
    'liveaboardDetails': (table: 'liveaboard_detail_records', pk: 'id'),
    'itineraryDays': (table: 'trip_itinerary_days', pk: 'id'),
    'equipment': (table: 'equipment', pk: 'id'),
    'equipmentSets': (table: 'equipment_sets', pk: 'id'),
    'diveTypes': (table: 'dive_types', pk: 'id'),
    'tankPresets': (table: 'tank_presets', pk: 'id'),
    'diveComputers': (table: 'dive_computers', pk: 'id'),
    'tags': (table: 'tags', pk: 'id'),
    'courses': (table: 'courses', pk: 'id'),
    'dives': (table: 'dives', pk: 'id'),
    'diveSites': (table: 'dive_sites', pk: 'id'),
    'certifications': (table: 'certifications', pk: 'id'),
    'serviceRecords': (table: 'service_records', pk: 'id'),
    'settings': (table: 'settings', pk: 'key'),
    'csvPresets': (table: 'csv_presets', pk: 'id'),
    'viewConfigs': (table: 'view_configs', pk: 'id'),
  };

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
        _log.warning(
          'Sync metadata read failed, attempting repair',
          error: e,
          stackTrace: stackTrace,
        );
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
      _log.error(
        'Failed to get or create sync metadata',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _repairSyncMetadataRow() async {
    final rows = await _db
        .customSelect(
          '''
      SELECT id, device_id, sync_version, created_at, updated_at
      FROM sync_metadata
      WHERE id = ?
      ''',
          variables: [Variable.withString(_globalMetadataId)],
        )
        .get();

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
        rawDeviceId.isEmpty ||
        rawSyncVersion == null ||
        rawSyncVersion is! int ||
        rawCreatedAt == null ||
        rawCreatedAt is! int ||
        rawUpdatedAt == null ||
        rawUpdatedAt is! int;

    if (!needsRepair) return;

    final deviceId = rawDeviceId is String && rawDeviceId.isNotEmpty
        ? rawDeviceId
        : _uuid.v4();
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

  /// Get this database's instance token, or null if none has been set yet
  /// (rows predating the column, or a freshly created/restored database).
  Future<String?> getInstanceToken() async {
    final metadata = await getOrCreateMetadata();
    return metadata.instanceToken;
  }

  /// Generate and persist a fresh instance token, returning it.
  ///
  /// Rotating the token on each launch is what lets a later restore of an older
  /// backup be detected even when the device id is unchanged: the backup
  /// carries a superseded token that no longer matches the copy mirrored
  /// outside the database. See [SyncInitializer.reconcileDeviceIdentity].
  Future<String> rotateInstanceToken() async {
    await getOrCreateMetadata();
    final token = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.syncMetadata,
    )..where((t) => t.id.equals(_globalMetadataId))).write(
      SyncMetadataCompanion(instanceToken: Value(token), updatedAt: Value(now)),
    );
    return token;
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
      _log.error(
        'Failed to update last sync time',
        error: e,
        stackTrace: stackTrace,
      );
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
      _log.error(
        'Failed to set cloud provider',
        error: e,
        stackTrace: stackTrace,
      );
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
      _log.error(
        'Failed to set remote file ID',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the remote file ID
  Future<String?> getRemoteFileId() async {
    final metadata = await getOrCreateMetadata();
    return metadata.remoteFileId;
  }

  /// The library epoch this device last accepted, or null in the pre-epoch
  /// world. Dual-anchored with LibraryEpochStore's SharedPreferences mirror.
  Future<String?> getLastAcceptedEpochId() async {
    final metadata = await getOrCreateMetadata();
    return metadata.lastAcceptedEpochId;
  }

  Future<void> setLastAcceptedEpochId(String? epochId) async {
    try {
      await getOrCreateMetadata();
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          lastAcceptedEpochId: Value(epochId),
          updatedAt: Value(now),
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set last accepted epoch id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
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

      // Mark-pending and the HLC stamp on the entity row are one logical write;
      // run them in a transaction so a crash can't leave the row pending with a
      // stale/absent HLC, and concurrent calls can't interleave the two steps.
      await _db.transaction(() async {
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

        await _stampHlc(entityType, recordId);
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark record pending: $entityType/$recordId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Stamp a fresh Hybrid Logical Clock onto the just-written entity row, if
  /// the entity is conflict-capable and the clock is configured. Centralised
  /// here (the write choke point) rather than in every repository companion.
  /// The row is expected to already exist (repositories mark pending after the
  /// insert/update); if it does not, the UPDATE is a harmless no-op.
  Future<void> _stampHlc(String entityType, String recordId) async {
    final target = _hlcTargets[entityType];
    if (target == null) return;
    await ensureSyncClockConfigured();
    final hlc = SyncClock.instance.issue();
    if (hlc == null) return;
    await _db.customStatement(
      'UPDATE "${target.table}" SET hlc = ? WHERE "${target.pk}" = ?',
      [hlc, recordId],
    );
  }

  /// Configure the process-wide [SyncClock] from this device's id and its
  /// persisted clock value, once per process. Lazy so the first local write
  /// stamps an HLC even before the first sync runs.
  Future<void> ensureSyncClockConfigured() async {
    if (SyncClock.instance.isConfigured) return;
    final metadata = await getOrCreateMetadata();
    // Seed from the greater of the persisted clock and the highest HLC already
    // stamped on any entity row, then force our own node id. The persisted
    // clock can lag the rows if the app was killed between syncs (it is only
    // persisted at sync time but advanced in memory per write); seeding from
    // the on-disk rows guarantees the next local write is never ordered behind
    // data this device already wrote -- which would otherwise let a remote win
    // a record the local device edited more recently.
    final seed = _seedHlc(
      metadata.deviceId,
      _parseHlc(metadata.hlc),
      _parseHlc(await _maxRowHlc()),
    );
    SyncClock.instance.configure(nodeId: metadata.deviceId, persisted: seed);
  }

  /// The highest `hlc` value across every conflict-capable table, or null if
  /// none has one yet. Lexically comparable because the packed format zero-pads
  /// physical time and counter.
  Future<String?> _maxRowHlc() async {
    final union = _hlcTargets.values
        .map((t) => 'SELECT MAX(hlc) AS h FROM "${t.table}"')
        .join(' UNION ALL ');
    final row = await _db
        .customSelect('SELECT MAX(h) AS m FROM ($union)')
        .getSingleOrNull();
    return row?.read<String?>('m');
  }

  /// Pick the greater of [a]/[b] by (physicalTime, counter) and rebuild it with
  /// [nodeId] so the clock always issues under THIS device's identity.
  Hlc? _seedHlc(String nodeId, Hlc? a, Hlc? b) {
    Hlc? best;
    for (final h in [a, b]) {
      if (h == null) continue;
      if (best == null ||
          h.physicalTime > best.physicalTime ||
          (h.physicalTime == best.physicalTime && h.counter > best.counter)) {
        best = h;
      }
    }
    if (best == null) return null;
    return Hlc(best.physicalTime, best.counter, nodeId);
  }

  /// Persist the current [SyncClock] value so the logical counter survives an
  /// app restart. Called by the sync flow after a sync completes.
  Future<void> persistSyncClock() async {
    final current = SyncClock.instance.current;
    if (current == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.syncMetadata,
    )..where((t) => t.id.equals(_globalMetadataId))).write(
      SyncMetadataCompanion(
        hlc: Value(current.toString()),
        updatedAt: Value(now),
      ),
    );
  }

  Hlc? _parseHlc(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return Hlc.parse(value);
    } catch (_) {
      return null;
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
        error: e,
        stackTrace: stackTrace,
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
        error: e,
        stackTrace: stackTrace,
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
      _log.error(
        'Failed to get pending records',
        error: e,
        stackTrace: stackTrace,
      );
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
      _log.error(
        'Failed to get conflict records',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get count of pending changes
  Future<int> getPendingCount() async {
    try {
      final records = await getPendingRecords();
      return records.length;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pending count',
        error: e,
        stackTrace: stackTrace,
      );
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
      _log.error(
        'Failed to clear pending sync records',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get count of conflicts
  Future<int> getConflictCount() async {
    try {
      final records = await getConflictRecords();
      return records.length;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get conflict count',
        error: e,
        stackTrace: stackTrace,
      );
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
        error: e,
        stackTrace: stackTrace,
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
      _log.error(
        'Failed to clear all sync records',
        error: e,
        stackTrace: stackTrace,
      );
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
        error: e,
        stackTrace: stackTrace,
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
      _log.error(
        'Failed to get deletions since: $since',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all deletions
  Future<List<DeletionLogData>> getAllDeletions() async {
    try {
      return _db.select(_db.deletionLog).get();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all deletions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Log a deletion if one doesn't already exist for the same record
  Future<void> logDeletionIfMissing({
    required String entityType,
    required String recordId,
    required int deletedAt,
  }) async {
    // Use .get() instead of .getSingleOrNull() to handle cases where
    // duplicate deletion entries exist (the schema allows this since
    // the primary key is a UUID, not the entityType+recordId combo).
    final existing =
        await (_db.select(_db.deletionLog)
              ..where((t) => t.entityType.equals(entityType))
              ..where((t) => t.recordId.equals(recordId)))
            .get();
    if (existing.isNotEmpty) return;
    await logDeletion(
      entityType: entityType,
      recordId: recordId,
      deletedAt: deletedAt,
    );
  }

  /// Remove the tombstone(s) for one record of [entityType]. The deletion log
  /// is a single table shared across entity types and recordIds are only unique
  /// within an entity type, so the delete matches BOTH [entityType] and
  /// [recordId]. Called when a remote edit newer than the deletion revives the
  /// record, so the obsolete tombstone stops re-deleting it on later syncs.
  Future<void> removeDeletion({
    required String entityType,
    required String recordId,
  }) async {
    try {
      await (_db.delete(_db.deletionLog)..where(
            (t) =>
                t.entityType.equals(entityType) & t.recordId.equals(recordId),
          ))
          .go();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to remove deletion: $entityType/$recordId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
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
      _log.error(
        'Failed to clear old deletions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Clear all deletions (after successful sync)
  Future<void> clearAllDeletions() async {
    try {
      await _db.delete(_db.deletionLog).go();
      _log.info('Cleared all deletions');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear all deletions',
        error: e,
        stackTrace: stackTrace,
      );
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

  /// Reset sync state (useful for testing or switching accounts).
  ///
  /// [clearDeletionLog] defaults to the historical full wipe (used by
  /// [rebaselineAfterRestore], where the restored log is the backup's stale
  /// snapshot). The user-facing Reset Sync State passes false: tombstones are
  /// data history, and wiping them lets any stale peer file re-insert every
  /// record deleted since that file was written.
  Future<void> resetSyncState({bool clearDeletionLog = true}) async {
    try {
      await clearAllSyncRecords();
      if (clearDeletionLog) {
        await clearAllDeletions();
      }

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
      _log.error(
        'Failed to reset sync state',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Overwrite the stored device id. Used to preserve this installation's sync
  /// identity across a database restore, which would otherwise replace it with
  /// the (possibly stale, possibly foreign) device id captured in the backup.
  Future<void> setDeviceId(String deviceId) async {
    if (deviceId.trim().isEmpty) {
      // A blank device id would corrupt sync identity (per-device file name and
      // HLC node id), so reject it rather than persist it.
      throw ArgumentError.value(
        deviceId,
        'deviceId',
        'device id must not be empty',
      );
    }
    try {
      await getOrCreateMetadata();
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(deviceId: Value(deviceId), updatedAt: Value(now)),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to set device id', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Re-baseline sync after a database restore.
  ///
  /// A restore replaces the entire database, so `sync_metadata` (device id,
  /// HLC clock, last-sync timestamp, cursors) and the deletion log all revert
  /// to the backup's stale snapshot. The merge gates on the persisted
  /// `lastSync` (`localUpdatedAt > lastSyncMs` reads almost every restored row
  /// as a conflict), so a rewound baseline stalls sync and lets a peer's
  /// still-live copy keep resurrecting deletes.
  ///
  /// Preserve the live device identity (captured by the caller *before* the
  /// restore) and clear the sync baseline so the next sync performs a clean
  /// full reconcile of the restored data instead of replaying a stale position.
  Future<void> rebaselineAfterRestore({
    String? preserveDeviceId,
    String? preserveEpochId,
  }) async {
    if (preserveDeviceId != null && preserveDeviceId.isNotEmpty) {
      await setDeviceId(preserveDeviceId);
    }
    await resetSyncState();
    // The restored database carries the backup's stale epoch; overwrite it
    // with the live value captured by the caller before the swap (or null
    // when this install has never accepted an epoch).
    await setLastAcceptedEpochId(preserveEpochId);
    // Drop the in-memory clock so it re-seeds from the restored rows under this
    // device's id on the next write. (issue() advances physical time to now()
    // regardless, so local writes are never ordered behind the restored data.)
    SyncClock.instance.reset();
  }
}
