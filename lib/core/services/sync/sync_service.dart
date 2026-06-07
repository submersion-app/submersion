import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' show SyncRecord;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:uuid/uuid.dart';

/// Sync operation result
enum SyncResultStatus {
  success,
  noChanges,
  hasConflicts,
  networkError,
  authError,
  error,
}

/// Result of a sync operation
class SyncResult {
  final SyncResultStatus status;
  final String? message;
  final int recordsSynced;
  final int conflictsFound;
  final DateTime? lastSyncTime;

  const SyncResult({
    required this.status,
    this.message,
    this.recordsSynced = 0,
    this.conflictsFound = 0,
    this.lastSyncTime,
  });

  bool get isSuccess =>
      status == SyncResultStatus.success ||
      status == SyncResultStatus.noChanges ||
      status == SyncResultStatus.hasConflicts;

  @override
  String toString() =>
      'SyncResult(status: $status, records: $recordsSynced, conflicts: $conflictsFound)';
}

class SyncStepException implements Exception {
  final String step;
  final Object error;

  SyncStepException(this.step, this.error);

  @override
  String toString() => 'Sync failed during $step: $error';
}

/// Progress callback for sync operations
typedef SyncProgressCallback = void Function(SyncProgress progress);

/// Sync progress information
class SyncProgress {
  final SyncPhase phase;
  final double progress; // 0.0 - 1.0
  final String? message;

  const SyncProgress({
    required this.phase,
    required this.progress,
    this.message,
  });
}

/// Phases of the sync operation
enum SyncPhase {
  preparing,
  exporting,
  uploading,
  downloading,
  importing,
  resolvingConflicts,
  complete,
}

/// Conflict information for user resolution
class SyncConflict {
  final String entityType;
  final String recordId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime localModified;
  final DateTime remoteModified;

  const SyncConflict({
    required this.entityType,
    required this.recordId,
    required this.localData,
    required this.remoteData,
    required this.localModified,
    required this.remoteModified,
  });

  String get displayName {
    // Try to get a meaningful name from the data
    return localData['name'] as String? ??
        localData['title'] as String? ??
        '$entityType #$recordId';
  }
}

/// Resolution choice for a conflict
enum ConflictResolution { keepLocal, keepRemote, keepBoth }

/// Core sync service that orchestrates cloud sync operations
class SyncService {
  final SyncRepository _syncRepository;
  final SyncDataSerializer _serializer;
  final CloudStorageProvider? _cloudProvider;
  final _log = LoggerService.forClass(SyncService);
  final _uuid = const Uuid();

  SyncProgressCallback? _progressCallback;

  SyncService({
    required SyncRepository syncRepository,
    required SyncDataSerializer serializer,
    CloudStorageProvider? cloudProvider,
  }) : _syncRepository = syncRepository,
       _serializer = serializer,
       _cloudProvider = cloudProvider;

  /// Set a callback to receive progress updates during sync
  void setProgressCallback(SyncProgressCallback? callback) {
    _progressCallback = callback;
  }

  void _reportProgress(SyncPhase phase, double progress, [String? message]) {
    _progressCallback?.call(
      SyncProgress(phase: phase, progress: progress, message: message),
    );
  }

  /// Check if sync is available (provider configured and authenticated)
  Future<bool> isSyncAvailable() async {
    final provider = _cloudProvider;
    if (provider == null) return false;
    if (!await provider.isAvailable()) return false;
    return provider.isAuthenticated();
  }

  /// Get the last successful sync time
  Future<DateTime?> getLastSyncTime() async {
    return _syncRepository.getLastSyncTime();
  }

  /// Check if there are local changes that haven't been synced
  Future<bool> hasUnsyncedChanges() async {
    return _syncRepository.hasUnsyncedChanges();
  }

  /// Get the number of pending changes
  Future<int> getPendingChangesCount() async {
    return _syncRepository.getPendingCount();
  }

  /// Get all current conflicts
  Future<List<SyncConflict>> getConflicts() async {
    final conflictRecords = await _syncRepository.getConflictRecords();
    final conflicts = <SyncConflict>[];

    for (final record in conflictRecords) {
      if (record.conflictData != null) {
        try {
          final remoteData = _parseConflictData(record.conflictData!);
          final localData = await _serializer.fetchRecord(
            record.entityType,
            record.recordId,
          );
          final remoteModified = _extractModifiedAt(remoteData);
          final localModified = _extractModifiedAt(localData ?? {});

          conflicts.add(
            SyncConflict(
              entityType: record.entityType,
              recordId: record.recordId,
              localData: localData ?? {},
              remoteData: remoteData,
              localModified:
                  localModified ??
                  DateTime.fromMillisecondsSinceEpoch(record.localUpdatedAt),
              remoteModified: remoteModified ?? DateTime.now(),
            ),
          );
        } catch (e) {
          _log.error(
            'Failed to parse conflict data for ${record.recordId}',
            error: e,
          );
        }
      }
    }

    return conflicts;
  }

  Map<String, dynamic> _parseConflictData(String json) {
    final parsed = jsonDecode(json);
    if (parsed is Map<String, dynamic>) {
      return parsed;
    }
    return {};
  }

  DateTime? _extractModifiedAt(Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'] as int?;
    if (updatedAt != null) {
      return DateTime.fromMillisecondsSinceEpoch(updatedAt);
    }
    final createdAt = data['createdAt'] as int?;
    if (createdAt != null) {
      return DateTime.fromMillisecondsSinceEpoch(createdAt);
    }
    return null;
  }

  /// Perform a full sync operation
  ///
  /// This will:
  /// 1. Export local changes to JSON
  /// 2. Download remote sync file (if exists)
  /// 3. Merge changes, detecting conflicts
  /// 4. Upload merged result
  /// 5. Update local sync state
  Future<SyncResult> performSync() async {
    _log.debug('performSync() called');
    final provider = _cloudProvider;
    if (provider == null) {
      _log.error('No cloud provider configured');
      return const SyncResult(
        status: SyncResultStatus.error,
        message: 'No cloud provider configured',
      );
    }

    _log.debug('Using provider: ${provider.providerName}');

    try {
      _reportProgress(SyncPhase.preparing, 0.0, 'Preparing sync...');

      // Check authentication
      final isAuth = await _withStep(
        'auth check',
        () => provider.isAuthenticated(),
      );
      _log.debug('isAuthenticated = $isAuth');
      if (!isAuth) {
        return const SyncResult(
          status: SyncResultStatus.authError,
          message: 'Not authenticated with cloud provider',
        );
      }

      // Get device ID and last sync time
      final deviceId = await _withStep(
        'load device id',
        () => _syncRepository.getDeviceId(),
      );
      final lastSyncTime = await _withStep(
        'load last sync time',
        () => _syncRepository.getLastSyncTime(),
      );
      // Make sure the HLC clock is live before merging so receiving remote
      // payloads advances it (and any writes during the sync get stamped).
      await _withStep(
        'configure sync clock',
        () => _syncRepository.ensureSyncClockConfigured(),
      );

      // Try to download existing remote file
      _reportProgress(
        SyncPhase.downloading,
        0.4,
        'Checking for remote data...',
      );

      // Resolve every sync file we should apply: all OTHER devices'
      // per-device files plus any legacy shared file. Our own per-device file
      // is excluded (it is our data, already local). Listing all files (rather
      // than a single canonical file) is what lets per-device files coexist
      // without a write-write race.
      List<CloudFileInfo> remoteFiles;
      try {
        remoteFiles = await _resolveRemoteSyncFiles(
          provider,
          deviceId,
        ).timeout(const Duration(seconds: 8));
      } on TimeoutException {
        _log.warning('Timed out listing remote sync files');
        remoteFiles = const [];
      } catch (e, stackTrace) {
        _log.warning(
          'Failed to list remote sync files: $e',
          stackTrace: stackTrace,
        );
        remoteFiles = const [];
      }

      _reportProgress(SyncPhase.importing, 0.6, 'Processing changes...');

      var recordsSynced = 0;
      var conflictsFound = 0;
      var recordsFailed = 0;

      for (final file in remoteFiles) {
        // NOTE: we intentionally do NOT skip files by their cloud
        // modifiedTime. iCloud Drive can fail to advance that metadata after a
        // conflict-copy merge, which would silently skip a file containing new
        // records; and skipping a file whose record failed to apply once would
        // drop it forever. Re-applying is idempotent (upsert + HLC), so we
        // always download and merge every foreign file.
        SyncPayload payload;
        try {
          final remoteData = await provider
              .downloadFile(file.id)
              .timeout(const Duration(seconds: 15));
          final remoteJson = _decodePayloadBytes(remoteData);
          final parsed = _serializer.deserializePayload(remoteJson);
          if (!_serializer.validateChecksum(parsed)) {
            _log.warning('Remote sync file ${file.name} has invalid checksum');
            continue;
          }
          payload = parsed;
        } on TimeoutException {
          _log.warning('Timed out downloading ${file.name}');
          continue;
        } catch (e, stackTrace) {
          _log.warning(
            'Failed to download/parse ${file.name}: $e',
            stackTrace: stackTrace,
          );
          continue;
        }

        // Skip our own data by payload identity (covers a legacy shared file
        // or an iCloud conflict-copy this device authored) -- applying it to
        // ourselves is a no-op that only inflates counts.
        if (payload.deviceId == deviceId) {
          continue;
        }

        final mergeResult = await _withStep(
          'apply remote data',
          () => _applyRemotePayload(payload, lastSyncTime),
        );
        recordsSynced += mergeResult.recordsApplied;
        conflictsFound += mergeResult.conflictsFound;
        recordsFailed += mergeResult.recordsFailed;
      }

      _reportProgress(SyncPhase.exporting, 0.7, 'Exporting local data...');

      final deletions = await _withStep(
        'load deletions',
        () => _syncRepository.getAllDeletions(),
      );
      final localPayload = await _withStep(
        'export local data',
        () => _serializer.exportData(
          deviceId: deviceId,
          since: null, // Full export for now
          lastSyncTimestamp: lastSyncTime?.millisecondsSinceEpoch,
          deletions: deletions,
        ),
      );

      _reportProgress(SyncPhase.exporting, 0.8, 'Serializing data...');

      final localJson = _withStepSync(
        'serialize local payload',
        () => _serializer.serializePayload(localPayload),
      );
      final localData = Uint8List.fromList(utf8.encode(localJson));

      _reportProgress(SyncPhase.uploading, 0.85, 'Uploading sync data...');

      final syncFolder = await _withStep(
        'resolve sync folder',
        () => provider.getOrCreateSyncFolder().timeout(
          const Duration(seconds: 10),
        ),
      );
      // Write to this device's own file so two devices never contend for the
      // same file (the iCloud "conflicted copy" race). Other devices pick this
      // up by listing the folder on their next sync.
      final filename = _deviceSyncFileName(deviceId);

      _log.debug(
        'Uploading ${localData.length} bytes to $syncFolder/$filename...',
      );
      final result = await _withStep(
        'upload sync file',
        () => provider
            .uploadFile(localData, filename, folderId: syncFolder)
            .timeout(const Duration(seconds: 180)),
      );
      _log.debug('Upload complete! fileId = ${result.fileId}');

      // Update sync state
      await _withStep(
        'store remote file id',
        () => _syncRepository.setRemoteFileId(result.fileId),
      );
      // Only advance lastSyncTime when every record applied. A failed apply
      // leaves no per-record retry marker, so advancing lastSync would let the
      // conflict-detection window move past it and the record would never be
      // retried -- permanent loss. Leaving lastSync unchanged means the next
      // sync re-pulls and re-applies (idempotent) so the failure is retried.
      if (recordsFailed == 0) {
        await _withStep(
          'store last sync time',
          () => _syncRepository.updateLastSyncTime(result.uploadTime),
        );
      }
      // Persist the HLC so the logical counter survives an app restart (it
      // was advanced by SyncClock.receive() while applying remote payloads).
      await _withStep(
        'persist sync clock',
        () => _syncRepository.persistSyncClock(),
      );

      // Keep deletions for propagation, but prune old entries
      await _withStep(
        'clear old deletions',
        () => _syncRepository.clearOldDeletions(),
      );
      await _withStep(
        'clear pending records',
        () => _syncRepository.clearPendingRecords(),
      );
      if (conflictsFound == 0) {
        await _withStep(
          'clear sync records',
          () => _syncRepository.clearAllSyncRecords(),
        );
      }

      _reportProgress(SyncPhase.complete, 1.0, 'Sync complete');

      _log.info('Sync completed successfully');

      if (recordsFailed > 0) {
        _log.error('$recordsFailed record(s) failed to apply during sync');
      }
      return SyncResult(
        status: recordsFailed > 0
            ? SyncResultStatus.error
            : (conflictsFound > 0
                  ? SyncResultStatus.hasConflicts
                  : SyncResultStatus.success),
        message: recordsFailed > 0
            ? '$recordsFailed record(s) failed to apply'
            : null,
        recordsSynced: recordsSynced,
        conflictsFound: conflictsFound,
        lastSyncTime: result.uploadTime,
      );
    } on TimeoutException {
      _log.warning('Sync timed out while uploading');
      return const SyncResult(
        status: SyncResultStatus.networkError,
        message: 'Sync timed out while uploading',
      );
    } on SyncStepException catch (e) {
      return SyncResult(status: SyncResultStatus.error, message: e.toString());
    } on CloudStorageException catch (e) {
      _log.error(
        'Cloud storage error during sync',
        error: e,
        stackTrace: e.stackTrace,
      );
      return SyncResult(
        status: SyncResultStatus.networkError,
        message: e.message,
      );
    } catch (e, stackTrace) {
      _log.error('Sync failed', error: e, stackTrace: stackTrace);
      return SyncResult(
        status: SyncResultStatus.error,
        message: _formatSyncError(e, stackTrace),
      );
    }
  }

  Future<T> _withStep<T>(String step, Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, stackTrace) {
      _log.error('Sync step failed: $step', error: e, stackTrace: stackTrace);
      throw SyncStepException(step, e);
    }
  }

  T _withStepSync<T>(String step, T Function() action) {
    try {
      return action();
    } catch (e, stackTrace) {
      _log.error('Sync step failed: $step', error: e, stackTrace: stackTrace);
      throw SyncStepException(step, e);
    }
  }

  String _formatSyncError(Object error, StackTrace stackTrace) {
    final trace = stackTrace.toString().split('\n');
    final location = trace.firstWhere(
      (line) => line.contains('lib/'),
      orElse: () => '',
    );
    if (location.isEmpty) {
      return error.toString();
    }
    final cleaned = location.trim().replaceFirst(RegExp(r'^#\\d+\\s+'), '');
    return '${error.toString()} ($cleaned)';
  }

  String _decodePayloadBytes(Uint8List data) {
    try {
      return utf8.decode(data);
    } catch (_) {
      return String.fromCharCodes(data);
    }
  }

  /// This device's own per-device sync filename.
  String _deviceSyncFileName(String deviceId) =>
      '${CloudStorageProviderMixin.syncFilePrefix}$deviceId'
      '${CloudStorageProviderMixin.syncFileExtension}';

  /// Resolve every remote sync file this device should apply: all other
  /// devices' per-device files, plus a legacy shared `submersion_sync.json`
  /// if one is still present. Excludes our own per-device file and any iCloud
  /// "conflicted copy" duplicates. Returns [] on failure.
  Future<List<CloudFileInfo>> _resolveRemoteSyncFiles(
    CloudStorageProvider provider,
    String deviceId,
  ) async {
    try {
      final ownFileName = _deviceSyncFileName(deviceId);
      final files = await provider.listFiles(
        namePattern: CloudStorageProviderMixin.syncFileStem,
      );
      return files
          .where((f) => !_isConflictCopy(f.name))
          .where((f) => f.name != ownFileName)
          .toList();
    } catch (e) {
      _log.warning('Failed to resolve remote sync files: $e');
      return const [];
    }
  }

  Future<_MergeResult> _applyRemotePayload(
    SyncPayload remotePayload,
    DateTime? localLastSync,
  ) async {
    // Wrap deletions + merge in a single transaction with deferred FK checks.
    // Without this, intra-payload references (e.g. a dive whose siteId points
    // at a dive site appearing later in the apply order, or a dive whose
    // courseId points at a course in the same payload) fail immediately and
    // the affected rows never reach the receiving DB. See
    // docs/superpowers/findings/2026-06-02-icloud-sync-diagnosis.md.
    return _serializer.applyInDeferredFkTransaction(
      () => _applyRemotePayloadInner(remotePayload, localLastSync),
    );
  }

  Future<_MergeResult> _applyRemotePayloadInner(
    SyncPayload remotePayload,
    DateTime? localLastSync,
  ) async {
    final lastSyncMs = localLastSync?.millisecondsSinceEpoch;
    var recordsApplied = 0;
    var conflictsFound = 0;
    var recordsFailed = 0;
    final pendingByEntity = await _pendingRecordMap();

    final deletionResult = await _applyRemoteDeletions(
      remotePayload.deletions,
      lastSyncMs,
      remotePayload.exportedAt,
      pendingByEntity,
    );
    recordsApplied += deletionResult.recordsApplied;
    conflictsFound += deletionResult.conflictsFound;
    recordsFailed += deletionResult.recordsFailed;

    final data = remotePayload.data;

    final mergeOrder =
        <
          ({String type, List<Map<String, dynamic>> records, bool hasUpdatedAt})
        >[
          (type: 'divers', records: data.divers, hasUpdatedAt: true),
          (
            type: 'diverSettings',
            records: data.diverSettings,
            hasUpdatedAt: true,
          ),
          (type: 'buddies', records: data.buddies, hasUpdatedAt: true),
          (type: 'diveCenters', records: data.diveCenters, hasUpdatedAt: true),
          (type: 'trips', records: data.trips, hasUpdatedAt: true),
          (
            type: 'liveaboardDetails',
            records: data.liveaboardDetails,
            hasUpdatedAt: true,
          ),
          (
            type: 'itineraryDays',
            records: data.itineraryDays,
            hasUpdatedAt: true,
          ),
          (type: 'equipment', records: data.equipment, hasUpdatedAt: true),
          (
            type: 'equipmentSets',
            records: data.equipmentSets,
            hasUpdatedAt: true,
          ),
          (
            type: 'equipmentSetItems',
            records: data.equipmentSetItems,
            hasUpdatedAt: false,
          ),
          (type: 'diveTypes', records: data.diveTypes, hasUpdatedAt: true),
          (type: 'tankPresets', records: data.tankPresets, hasUpdatedAt: true),
          (
            type: 'diveComputers',
            records: data.diveComputers,
            hasUpdatedAt: true,
          ),
          (type: 'species', records: data.species, hasUpdatedAt: false),
          (type: 'tags', records: data.tags, hasUpdatedAt: true),
          // Courses must apply before dives/certifications that reference them.
          // (Deferred FK already covers ordering, but keep the logical sequence
          // so a future read of this list still tells the dependency story.)
          (type: 'courses', records: data.courses, hasUpdatedAt: true),
          (type: 'dives', records: data.dives, hasUpdatedAt: true),
          (type: 'diveSites', records: data.diveSites, hasUpdatedAt: true),
          (type: 'diveTanks', records: data.diveTanks, hasUpdatedAt: false),
          (type: 'diveWeights', records: data.diveWeights, hasUpdatedAt: false),
          (
            type: 'diveEquipment',
            records: data.diveEquipment,
            hasUpdatedAt: false,
          ),
          (type: 'diveTags', records: data.diveTags, hasUpdatedAt: false),
          (type: 'diveBuddies', records: data.diveBuddies, hasUpdatedAt: false),
          (
            type: 'diveProfiles',
            records: data.diveProfiles,
            hasUpdatedAt: false,
          ),
          (
            type: 'diveProfileEvents',
            records: data.diveProfileEvents,
            hasUpdatedAt: false,
          ),
          (type: 'gasSwitches', records: data.gasSwitches, hasUpdatedAt: false),
          // Extra entities added in the SyncData expansion. Four are
          // append-only and use the blind-upsert merge path (no updatedAt
          // column: diveCustomFields, diveDataSources, siteSpecies,
          // fieldPresets). Two carry updatedAt and use the standard
          // conflict-detection path (csvPresets, viewConfigs). FK ordering
          // is handled by the deferred-FK transaction wrapping this loop.
          (
            type: 'diveCustomFields',
            records: data.diveCustomFields,
            hasUpdatedAt: false,
          ),
          (
            type: 'diveDataSources',
            records: data.diveDataSources,
            hasUpdatedAt: false,
          ),
          (type: 'siteSpecies', records: data.siteSpecies, hasUpdatedAt: false),
          (type: 'csvPresets', records: data.csvPresets, hasUpdatedAt: true),
          (type: 'viewConfigs', records: data.viewConfigs, hasUpdatedAt: true),
          (
            type: 'fieldPresets',
            records: data.fieldPresets,
            hasUpdatedAt: false,
          ),
          (
            type: 'tankPressureProfiles',
            records: data.tankPressureProfiles,
            hasUpdatedAt: false,
          ),
          (type: 'tideRecords', records: data.tideRecords, hasUpdatedAt: false),
          (type: 'sightings', records: data.sightings, hasUpdatedAt: false),
          (
            type: 'certifications',
            records: data.certifications,
            hasUpdatedAt: true,
          ),
          (
            type: 'serviceRecords',
            records: data.serviceRecords,
            hasUpdatedAt: true,
          ),
          (type: 'settings', records: data.settings, hasUpdatedAt: true),
          (type: 'media', records: data.media, hasUpdatedAt: false),
        ];

    for (final entry in mergeOrder) {
      final result = await _mergeEntity(
        entityType: entry.type,
        records: entry.records,
        hasUpdatedAt: entry.hasUpdatedAt,
        lastSyncMs: lastSyncMs,
        pendingRecordIds: pendingByEntity[entry.type] ?? const <String>{},
      );
      recordsApplied += result.recordsApplied;
      conflictsFound += result.conflictsFound;
      recordsFailed += result.recordsFailed;
    }

    return _MergeResult(
      recordsApplied: recordsApplied,
      conflictsFound: conflictsFound,
      recordsFailed: recordsFailed,
    );
  }

  Future<_MergeResult> _applyRemoteDeletions(
    Map<String, List<SyncDeletion>> deletions,
    int? lastSyncMs,
    int remoteExportedAt,
    Map<String, Set<String>> pendingByEntity,
  ) async {
    var applied = 0;
    var conflicts = 0;
    var failed = 0;

    for (final entry in deletions.entries) {
      final entityType = entry.key;
      for (final deletion in entry.value) {
        final recordId = deletion.id;
        try {
          if (pendingByEntity[entityType]?.contains(recordId) == true) {
            continue;
          }
          final local = await _serializer.fetchRecord(entityType, recordId);
          // _extractUpdatedAtMillis falls back to createdAt, so a row that was
          // created locally after our last sync is protected from a stale
          // remote tombstone even on append-only child tables that have a
          // createdAt. The handful of child tables with neither updatedAt nor
          // createdAt (dive_profiles, dive_tanks, dive_equipment,
          // tank_pressure_profiles, sightings) have no age signal; they are
          // regenerated wholesale with fresh ids on re-import, so a stale
          // tombstone won't match a current row.
          final localUpdatedAt = _extractUpdatedAtMillis(local);
          final deletionTimestamp = deletion.deletedAt > 0
              ? deletion.deletedAt
              : remoteExportedAt;

          final hasConflict =
              localUpdatedAt != null &&
              lastSyncMs != null &&
              localUpdatedAt > lastSyncMs;

          if (hasConflict) {
            conflicts += 1;
            await _syncRepository.markRecordConflict(
              entityType: entityType,
              recordId: recordId,
              conflictDataJson: jsonEncode({
                '_deleted': true,
                'deletedAt': deletionTimestamp,
                'recordId': recordId,
              }),
              localUpdatedAt: localUpdatedAt,
            );
            continue;
          }

          await _serializer.deleteRecord(entityType, recordId);
          await _syncRepository.logDeletionIfMissing(
            entityType: entityType,
            recordId: recordId,
            deletedAt: deletionTimestamp,
          );
          applied += 1;
        } catch (e, stackTrace) {
          // A failed deletion is a real failure (surfaced via recordsFailed),
          // not a conflict, and must not abort the rest of the batch.
          _log.error(
            'Failed to apply deletion $entityType/$recordId',
            error: e,
            stackTrace: stackTrace,
          );
          failed += 1;
        }
      }
    }

    return _MergeResult(
      recordsApplied: applied,
      conflictsFound: conflicts,
      recordsFailed: failed,
    );
  }

  Future<_MergeResult> _mergeEntity({
    required String entityType,
    required List<Map<String, dynamic>> records,
    required bool hasUpdatedAt,
    required int? lastSyncMs,
    required Set<String> pendingRecordIds,
  }) async {
    if (records.isEmpty) {
      return const _MergeResult(recordsApplied: 0, conflictsFound: 0);
    }

    var applied = 0;
    var conflicts = 0;
    var failed = 0;

    for (final record in records) {
      String? recordId;
      int? localUpdatedAt;
      try {
        recordId = _recordIdForEntity(entityType, record);
        if (recordId == null) {
          // A record with no resolvable id is malformed data, not a two-sided
          // conflict -- count it as a failure so performSync surfaces an error.
          _log.error('Skipping $entityType record with no resolvable id');
          failed += 1;
          continue;
        }

        if (pendingRecordIds.contains(recordId)) {
          continue;
        }

        if (!hasUpdatedAt) {
          await _serializer.upsertRecord(entityType, record);
          applied += 1;
          continue;
        }

        final local = await _serializer.fetchRecord(entityType, recordId);
        localUpdatedAt = _extractUpdatedAtMillis(local);
        final remoteUpdatedAt = _extractUpdatedAtMillis(record);

        final localHlc = _extractHlc(local);
        final remoteHlc = _extractHlc(record);
        // Advance our clock past every remote HLC we observe, so this device's
        // next local write is ordered after what it has seen (the skew fix).
        if (remoteHlc != null) {
          SyncClock.instance.receive(remoteHlc);
        }

        // When BOTH sides carry an HLC it is the authoritative, deterministic
        // resolution -- it already encodes causal order across devices, so we
        // do NOT raise a manual conflict (that would defeat the purpose of the
        // clock for the common concurrent-edit case). A strictly-greater
        // remote HLC wins; an exact tie or a local-newer HLC keeps local.
        if (localHlc != null && remoteHlc != null) {
          if (remoteHlc.compareTo(localHlc) > 0) {
            await _serializer.upsertRecord(entityType, record);
            applied += 1;
          }
          continue;
        }

        // Pre-HLC fallback (one or both sides lack an HLC): use updatedAt, and
        // surface a true two-sided edit since the last sync as a conflict.
        if (localUpdatedAt != null &&
            remoteUpdatedAt != null &&
            lastSyncMs != null &&
            localUpdatedAt > lastSyncMs &&
            remoteUpdatedAt > lastSyncMs &&
            remoteUpdatedAt != localUpdatedAt) {
          conflicts += 1;
          await _syncRepository.markRecordConflict(
            entityType: entityType,
            recordId: recordId,
            conflictDataJson: jsonEncode(record),
            localUpdatedAt: localUpdatedAt,
          );
          continue;
        }

        if (remoteUpdatedAt == null ||
            localUpdatedAt == null ||
            remoteUpdatedAt >= localUpdatedAt) {
          await _serializer.upsertRecord(entityType, record);
          applied += 1;
        }
      } catch (e, stackTrace) {
        _log.error(
          'Failed to merge $entityType record ${recordId ?? '(unknown)'}',
          error: e,
          stackTrace: stackTrace,
        );
        // An apply error is a real failure, not a "conflict" (which means both
        // sides edited the same record). Masking apply errors as conflicts is
        // what hid the cross-device no-op; count it so performSync surfaces it.
        failed += 1;
      }
    }

    return _MergeResult(
      recordsApplied: applied,
      conflictsFound: conflicts,
      recordsFailed: failed,
    );
  }

  Future<Map<String, Set<String>>> _pendingRecordMap() async {
    final records = await _syncRepository.getPendingRecords();
    final map = <String, Set<String>>{};
    for (final record in records) {
      map.putIfAbsent(record.entityType, () => <String>{}).add(record.recordId);
    }
    return map;
  }

  int? _extractUpdatedAtMillis(Map<String, dynamic>? data) {
    if (data == null) return null;
    final updatedAt = data['updatedAt'];
    if (updatedAt is int) return updatedAt;
    final createdAt = data['createdAt'];
    if (createdAt is int) return createdAt;
    return null;
  }

  /// Parse a record's Hybrid Logical Clock, or null if absent/blank (rows
  /// written before the HLC rollout). Malformed values are treated as absent
  /// so a bad value can never crash the merge.
  Hlc? _extractHlc(Map<String, dynamic>? data) {
    final raw = data?['hlc'];
    if (raw is! String || raw.isEmpty) return null;
    try {
      return Hlc.parse(raw);
    } catch (_) {
      return null;
    }
  }

  String? _recordIdForEntity(String entityType, Map<String, dynamic> record) {
    switch (entityType) {
      case 'settings':
        return record['key'] as String?;
      case 'diveEquipment':
        return record['id'] as String? ??
            _compositeId(record['diveId'], record['equipmentId']);
      case 'equipmentSetItems':
        return record['id'] as String? ??
            _compositeId(record['setId'], record['equipmentId']);
      default:
        return record['id'] as String?;
    }
  }

  String? _compositeId(Object? left, Object? right) {
    if (left == null || right == null) return null;
    return '$left|$right';
  }

  bool _isConflictCopy(String filename) {
    final lower = filename.toLowerCase();
    return lower.contains('conflicted copy') || lower.contains('conflict');
  }

  /// Resolve a conflict with the user's chosen resolution
  Future<void> resolveConflict(
    String entityType,
    String recordId,
    ConflictResolution resolution,
  ) async {
    _log.info('Resolving conflict for $entityType/$recordId with $resolution');

    final conflicts = await _syncRepository.getConflictRecords();
    SyncRecord? match;
    for (final conflict in conflicts) {
      if (conflict.entityType == entityType && conflict.recordId == recordId) {
        match = conflict;
        break;
      }
    }

    if (match == null || match.conflictData == null) {
      await _syncRepository.clearConflict(
        entityType: entityType,
        recordId: recordId,
      );
      return;
    }

    final remoteData = _parseConflictData(match.conflictData!);
    final isDeletion = remoteData['_deleted'] == true;
    final deletedAt = remoteData['deletedAt'] is int
        ? remoteData['deletedAt'] as int
        : null;

    switch (resolution) {
      case ConflictResolution.keepLocal:
        await _syncRepository.clearConflict(
          entityType: entityType,
          recordId: recordId,
        );
        await _markPendingForConflict(entityType, recordId);
        break;

      case ConflictResolution.keepRemote:
        if (isDeletion) {
          await _serializer.deleteRecord(entityType, recordId);
          await _syncRepository.logDeletionIfMissing(
            entityType: entityType,
            recordId: recordId,
            deletedAt: deletedAt ?? DateTime.now().millisecondsSinceEpoch,
          );
        } else {
          await _serializer.upsertRecord(entityType, remoteData);
        }
        await _syncRepository.clearConflict(
          entityType: entityType,
          recordId: recordId,
        );
        break;

      case ConflictResolution.keepBoth:
        if (isDeletion) {
          await _syncRepository.clearConflict(
            entityType: entityType,
            recordId: recordId,
          );
          await _markPendingForConflict(entityType, recordId);
          break;
        }
        final newId = _duplicateId(entityType, remoteData);
        if (newId != null) {
          remoteData['id'] = newId;
          await _serializer.upsertRecord(entityType, remoteData);
        }
        await _syncRepository.clearConflict(
          entityType: entityType,
          recordId: recordId,
        );
        await _markPendingForConflict(entityType, recordId);
        break;
    }
  }

  Future<void> _markPendingForConflict(
    String entityType,
    String recordId,
  ) async {
    final local = await _serializer.fetchRecord(entityType, recordId);
    final localUpdatedAt =
        _extractUpdatedAtMillis(local) ?? DateTime.now().millisecondsSinceEpoch;
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: recordId,
      localUpdatedAt: localUpdatedAt,
    );
  }

  String? _duplicateId(String entityType, Map<String, dynamic> record) {
    if (entityType == 'settings') return null;
    if (record['id'] == null) return null;
    return _uuid.v4();
  }

  /// Reset sync state (for debugging or account changes)
  Future<void> resetSyncState() async {
    await _syncRepository.resetSyncState();
    _log.info('Sync state reset');
  }

  /// Sign out from the current cloud provider
  Future<void> signOut() async {
    await _cloudProvider?.signOut();
    await _syncRepository.setCloudProvider(null);
    await _syncRepository.setRemoteFileId(null);
    _log.info('Signed out from cloud provider');
  }
}

class _MergeResult {
  final int recordsApplied;
  final int conflictsFound;
  final int recordsFailed;

  const _MergeResult({
    required this.recordsApplied,
    required this.conflictsFound,
    this.recordsFailed = 0,
  });
}
