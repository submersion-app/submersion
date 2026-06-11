import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' show SyncRecord;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
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
  final bool adoptedFreshIdentity;

  const SyncResult({
    required this.status,
    this.message,
    this.recordsSynced = 0,
    this.conflictsFound = 0,
    this.lastSyncTime,
    this.adoptedFreshIdentity = false,
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

/// A foreign-key reference from a synced child record to a parent whose
/// deletion is tracked in the deletion log. [nullable] distinguishes a cascade
/// child (NOT NULL -> the row cannot exist without the parent) from a set-null
/// reference (nullable -> the row survives with the reference cleared).
typedef ParentRef = ({String field, String parent, bool nullable});

/// Core sync service that orchestrates cloud sync operations
class SyncService {
  final SyncRepository _syncRepository;
  final SyncDataSerializer _serializer;
  final CloudStorageProvider? _cloudProvider;
  final SyncInitializer? _syncInitializer;

  /// Library epoch persistence (restore Replace mode). Nullable so existing
  /// constructions keep working; epoch gating activates only when provided.
  final LibraryEpochStore? _epochStore;
  final _log = LoggerService.forClass(SyncService);
  final _uuid = const Uuid();

  SyncProgressCallback? _progressCallback;

  SyncService({
    required SyncRepository syncRepository,
    required SyncDataSerializer serializer,
    CloudStorageProvider? cloudProvider,
    SyncInitializer? syncInitializer,
    LibraryEpochStore? epochStore,
  }) : _syncRepository = syncRepository,
       _serializer = serializer,
       _cloudProvider = cloudProvider,
       _syncInitializer = syncInitializer,
       _epochStore = epochStore;

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
      var deviceId = await _withStep(
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

      // List every sync file in the folder. We need the full list (not just
      // peers) so we can inspect our OWN file for a twin-identity signal
      // before deciding which files to merge.
      List<CloudFileInfo> allFiles;
      try {
        allFiles = await _listSyncFiles(
          provider,
        ).timeout(const Duration(seconds: 8));
      } on TimeoutException {
        _log.warning('Timed out listing remote sync files');
        allFiles = const [];
      } catch (e, stackTrace) {
        _log.warning(
          'Failed to list remote sync files: $e',
          stackTrace: stackTrace,
        );
        allFiles = const [];
      }

      var adoptedFreshIdentity = false;
      var ownFileName = _deviceSyncFileName(deviceId);
      final ownFile = allFiles.where((f) => f.name == ownFileName).firstOrNull;

      // Twin-identity check: our own cloud file carrying a nonce we never
      // minted means another install is syncing as this device (a clone from
      // whole-container OS migration). The launch-time anchor reconcile is
      // structurally blind to that (both installs' anchors match their own
      // DBs), so this in-band signal is the only detection point. Recovery:
      // adopt a fresh identity NOW and keep going -- the shared file then
      // counts as a peer below and the twins converge in this same sync.
      //
      // Accepted trade-off: a SharedPreferences wipe with the database kept
      // (rare outside dev machines) is indistinguishable from a DB clone and
      // reads as a twin. The design errs toward detection -- an identity
      // change is cheap and converges, silent twinning corrupts both sides.
      final initializer = _syncInitializer;
      if (ownFile != null && initializer != null) {
        final ownIdentity = await _peekPayloadIdentity(provider, ownFile);
        if (ownIdentity != null &&
            ownIdentity.deviceId == deviceId &&
            initializer.isForeignUploadNonce(
              ownIdentity.uploadNonce,
              provider.providerId,
            )) {
          _log.warning(
            'Another install is uploading as this device id; adopting a '
            'fresh sync identity to split the twins',
          );
          deviceId = await _withStep(
            'adopt fresh identity',
            () => initializer.adoptFreshIdentity(),
          );
          ownFileName = _deviceSyncFileName(deviceId);
          adoptedFreshIdentity = true;
          // Re-seed the HLC clock under the new node id now, so remote HLCs
          // received while merging the converging files below advance it
          // instead of no-opping against an unconfigured clock.
          await _withStep(
            'configure sync clock',
            () => _syncRepository.ensureSyncClockConfigured(),
          );
        }
      }

      // Resolve every sync file we should apply: all OTHER devices'
      // per-device files plus any legacy shared file. Our own per-device file
      // is excluded (it is our data, already local). Listing all files (rather
      // than a single canonical file) is what lets per-device files coexist
      // without a write-write race.
      final remoteFiles = allFiles.where((f) => f.name != ownFileName).toList();

      _reportProgress(SyncPhase.importing, 0.6, 'Processing changes...');

      var recordsSynced = 0;
      var conflictsFound = 0;
      var recordsFailed = 0;
      CloudFileInfo? mergedLegacyFile;

      for (final file in remoteFiles) {
        // NOTE: we intentionally do NOT skip files by their cloud
        // modifiedTime. iCloud Drive can fail to advance that metadata after a
        // conflict-copy merge, which would silently skip a file containing new
        // records; and skipping a file whose record failed to apply once would
        // drop it forever. Re-applying is idempotent (upsert + HLC), so we
        // always download and merge every foreign file.
        final payload = await _downloadAndParsePayload(provider, file);
        if (payload == null) {
          continue;
        }

        if (file.name == CloudStorageProviderMixin.canonicalSyncFileName) {
          // Parsed fine: its content is either our own pre-upgrade upload or
          // about to be merged below. Either way it is fully represented by
          // the per-device file we upload at the end of this sync, so it can
          // be retired afterwards.
          mergedLegacyFile = file;
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
      final uploadNonce = _uuid.v4();
      final localPayload = await _withStep(
        'export local data',
        () => _serializer.exportData(
          deviceId: deviceId,
          since: null, // Full export for now
          lastSyncTimestamp: lastSyncTime?.millisecondsSinceEpoch,
          deletions: deletions,
          uploadNonce: uploadNonce,
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
      // Record the nonce BEFORE uploading: if the upload succeeds but the
      // response is lost (timeout, app death), the cloud file carries this
      // nonce -- an unrecorded copy of it would read as a twin on the next
      // sync and force a needless identity change. The failure branch removes
      // the speculative entry so repeated failed uploads cannot evict the
      // nonce of the last successful upload from the ring.
      await _syncInitializer?.recordUploadNonce(
        uploadNonce,
        provider.providerId,
      );
      UploadResult result;
      try {
        result = await _withStep(
          'upload sync file',
          () => provider
              .uploadFile(localData, filename, folderId: syncFolder)
              .timeout(const Duration(seconds: 180)),
        );
      } catch (e) {
        // A timed-out upload may still have landed server-side; keep the
        // speculative nonce so our own file cannot read as a foreign twin
        // on the next sync (the ring absorbs the extra entry). Remove it
        // only on definite failures, so repeated hard failures cannot
        // evict the nonce of the last successful upload.
        final cause = e is SyncStepException ? e.error : e;
        if (cause is! TimeoutException) {
          await _syncInitializer?.removeUploadNonce(
            uploadNonce,
            provider.providerId,
          );
        }
        rethrow;
      }
      _log.debug('Upload complete! fileId = ${result.fileId}');

      // Deliberately do NOT persist result.fileId as "the remote file id":
      // under per-device files it is *our own* file, and the only consumer
      // (SyncInitializer.checkSyncOnLaunch) now inspects every peer file's
      // mtime directly. Persisting our own id made the launch check compare our
      // own upload time and miss other devices' changes.

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
      // Retire the legacy shared sync file once its content is merged and
      // re-published in this device's per-device file. Only when every record
      // applied: a failed apply relies on re-pulling the same file next sync.
      // Best-effort -- a still-active pre-per-device build recreates the file
      // on its next sync (uploads are full snapshots), so deletion never
      // loses data.
      if (recordsFailed == 0 && mergedLegacyFile != null) {
        try {
          await provider
              .deleteFile(mergedLegacyFile.id)
              .timeout(const Duration(seconds: 8));
          _log.info('Retired legacy shared sync file after merging it');
        } catch (e) {
          _log.warning('Could not retire legacy sync file: $e');
        }
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
            : (adoptedFreshIdentity
                  ? 'Another device was syncing with this device\'s '
                        'identity. This device adopted a new identity and '
                        'merged the cloud data.'
                  : null),
        recordsSynced: recordsSynced,
        conflictsFound: conflictsFound,
        // Mirror the persistence decision above: only report an advanced
        // lastSyncTime when every record applied (and we actually wrote it to
        // the DB). On a partial-apply failure lastSync is intentionally left
        // unchanged, so returning it here would make the result disagree with
        // stored state.
        lastSyncTime: recordsFailed == 0 ? result.uploadTime : null,
        adoptedFreshIdentity: adoptedFreshIdentity,
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

  /// Read just the envelope identity of a sync file: who wrote it and with
  /// which upload nonce. Used by the twin check on our OWN file, where the
  /// full parse (checksum over the whole data section, SyncData
  /// construction) would be pure overhead -- integrity is irrelevant to the
  /// question "did another install write this?", and after an adoption the
  /// file is re-downloaded and fully validated as a peer anyway. Returns
  /// null on any failure.
  Future<({String deviceId, String? uploadNonce})?> _peekPayloadIdentity(
    CloudStorageProvider provider,
    CloudFileInfo file,
  ) async {
    try {
      final bytes = await provider
          .downloadFile(file.id)
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(_decodePayloadBytes(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      final deviceId = decoded['deviceId'];
      if (deviceId is! String) return null;
      final nonce = decoded['uploadNonce'];
      return (deviceId: deviceId, uploadNonce: nonce is String ? nonce : null);
    } catch (e) {
      _log.warning('Could not inspect own sync file ${file.name}: $e');
      return null;
    }
  }

  /// Download and parse one remote sync file. Returns null (after logging)
  /// when the file cannot be fetched, fails checksum validation, or was
  /// written by a NEWER format version than this build understands --
  /// applying a future format would have undefined semantics, so it is
  /// skipped until the app is updated.
  Future<SyncPayload?> _downloadAndParsePayload(
    CloudStorageProvider provider,
    CloudFileInfo file,
  ) async {
    try {
      final remoteData = await provider
          .downloadFile(file.id)
          .timeout(const Duration(seconds: 15));
      final remoteJson = _decodePayloadBytes(remoteData);
      final parsed = _serializer.deserializePayload(remoteJson);
      if (parsed.version > syncFormatVersion) {
        _log.warning(
          'Remote sync file ${file.name} uses format v${parsed.version} '
          '(this build understands v$syncFormatVersion); update the app on '
          'this device to merge it',
        );
        return null;
      }
      if (!_serializer.validateChecksum(parsed)) {
        _log.warning('Remote sync file ${file.name} has invalid checksum');
        return null;
      }
      return parsed;
    } on TimeoutException {
      _log.warning('Timed out downloading ${file.name}');
      return null;
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to download/parse ${file.name}: $e',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// This device's own per-device sync filename.
  String _deviceSyncFileName(String deviceId) =>
      '${CloudStorageProviderMixin.syncFilePrefix}$deviceId'
      '${CloudStorageProviderMixin.syncFileExtension}';

  /// List every sync file in the folder (excluding iCloud conflict copies).
  /// Returns the full list including this device's own file so callers can
  /// inspect it before deciding which files to merge.
  Future<List<CloudFileInfo>> _listSyncFiles(
    CloudStorageProvider provider,
  ) async {
    final files = await provider.listFiles(
      namePattern: CloudStorageProviderMixin.syncFileStem,
    );
    return files.where((f) => !_isConflictCopy(f.name)).toList();
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

    // Local tombstones (including any just applied from this payload's
    // deletions) guard the merge below: a remote LIVE record must not
    // resurrect a record we have deleted unless the remote edit is newer than
    // our deletion. Loaded after _applyRemoteDeletions so a tombstone arriving
    // in the same payload also protects against a self-contradictory payload
    // that carries both a delete and a stale live copy of the same record.
    final tombstonesByEntity = await _deletionMap();

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

    // Precompute the locally-tombstoned parents this payload will REVIVE (a
    // remote edit strictly newer than our deletion). A child must not be
    // dropped/cleared for a parent that is coming back. The merge order does
    // not guarantee a parent is processed before its children, and a revival
    // only clears the tombstone in the DB (not the in-memory snapshot used by
    // the guard below), so this is computed up front to stay order-independent.
    final recordsByType = {for (final e in mergeOrder) e.type: e};
    final revivedParents = <String, Set<String>>{};
    final parentTypes = <String>{
      for (final refs in parentRefs.values)
        for (final ref in refs) ref.parent,
    };
    for (final parentType in parentTypes) {
      final tombs = tombstonesByEntity[parentType];
      final entry = recordsByType[parentType];
      if (tombs == null ||
          tombs.isEmpty ||
          entry == null ||
          !entry.hasUpdatedAt) {
        continue;
      }
      for (final rec in entry.records) {
        final id = _recordIdForEntity(parentType, rec);
        if (id == null) continue;
        final deletedAt = tombs[id];
        if (deletedAt == null) continue;
        final remoteUpdatedAt = _extractUpdatedAtMillis(rec);
        if (remoteUpdatedAt != null && remoteUpdatedAt > deletedAt) {
          revivedParents.putIfAbsent(parentType, () => <String>{}).add(id);
        }
      }
    }

    for (final entry in mergeOrder) {
      final result = await _mergeEntity(
        entityType: entry.type,
        records: entry.records,
        hasUpdatedAt: entry.hasUpdatedAt,
        lastSyncMs: lastSyncMs,
        pendingRecordIds: pendingByEntity[entry.type] ?? const <String>{},
        allTombstones: tombstonesByEntity,
        revivedParents: revivedParents,
      );
      recordsApplied += result.recordsApplied;
      conflictsFound += result.conflictsFound;
      recordsFailed += result.recordsFailed;
    }

    // Integrity backstop: applying a remote deletion of a parent can leave a
    // local row pointing at it via a non-cascading FK, which would fail the
    // deferred-FK COMMIT and abort the whole sync. Clear or delete any such
    // dangling reference before the transaction commits. (The merge guard
    // above stops a peer's orphan from being re-added, so this does not loop.)
    await _serializer.repairDanglingForeignKeys();

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

  /// Every synced child -> parent FK whose parent can be deleted (and thus
  /// tombstoned in the deletion log). Used by [_mergeEntity] to keep a peer's
  /// live child from dangling its FK against a parent we have deleted -- which
  /// would otherwise fail the deferred-FK COMMIT and abort the whole sync.
  /// NOT NULL (nullable: false) children are skipped; nullable references are
  /// cleared so the row survives detached.
  ///
  /// Generated from every `references(<deletable parent>, ...)` in the schema;
  /// completeness (and column nullability) is asserted against the live schema
  /// by sync_parent_refs_completeness_test.dart, so a new FK to a deletable
  /// parent fails that test until it is added here. (diverId is intentionally
  /// absent: diver deletion goes through DiverMergeRepository, which repoints
  /// FKs rather than orphaning them.)
  @visibleForTesting
  static const Map<String, List<ParentRef>> parentRefs = {
    'dives': [
      (field: 'siteId', parent: 'diveSites', nullable: true),
      (field: 'tripId', parent: 'trips', nullable: true),
      (field: 'courseId', parent: 'courses', nullable: true),
      (field: 'computerId', parent: 'diveComputers', nullable: true),
      (field: 'diveCenterId', parent: 'diveCenters', nullable: true),
    ],
    'diveProfiles': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'computerId', parent: 'diveComputers', nullable: true),
    ],
    'diveTanks': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'equipmentId', parent: 'equipment', nullable: true),
    ],
    'diveWeights': [(field: 'diveId', parent: 'dives', nullable: false)],
    'diveEquipment': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'equipmentId', parent: 'equipment', nullable: false),
    ],
    'diveBuddies': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'buddyId', parent: 'buddies', nullable: false),
    ],
    'diveTags': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'tagId', parent: 'tags', nullable: false),
    ],
    'diveProfileEvents': [(field: 'diveId', parent: 'dives', nullable: false)],
    'gasSwitches': [(field: 'diveId', parent: 'dives', nullable: false)],
    'diveCustomFields': [(field: 'diveId', parent: 'dives', nullable: false)],
    'tankPressureProfiles': [
      (field: 'diveId', parent: 'dives', nullable: false),
    ],
    'tideRecords': [(field: 'diveId', parent: 'dives', nullable: false)],
    'diveDataSources': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'computerId', parent: 'diveComputers', nullable: true),
    ],
    'sightings': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'speciesId', parent: 'species', nullable: false),
    ],
    'media': [
      (field: 'diveId', parent: 'dives', nullable: true),
      (field: 'siteId', parent: 'diveSites', nullable: true),
      (field: 'signerId', parent: 'buddies', nullable: true),
    ],
    'siteSpecies': [
      (field: 'siteId', parent: 'diveSites', nullable: false),
      (field: 'speciesId', parent: 'species', nullable: false),
    ],
    'liveaboardDetails': [(field: 'tripId', parent: 'trips', nullable: false)],
    'itineraryDays': [(field: 'tripId', parent: 'trips', nullable: false)],
    'certifications': [(field: 'courseId', parent: 'courses', nullable: true)],
    'courses': [(field: 'instructorId', parent: 'buddies', nullable: true)],
    'equipmentSetItems': [
      (field: 'setId', parent: 'equipmentSets', nullable: false),
      (field: 'equipmentId', parent: 'equipment', nullable: false),
    ],
    'serviceRecords': [
      (field: 'equipmentId', parent: 'equipment', nullable: false),
    ],
  };

  Future<_MergeResult> _mergeEntity({
    required String entityType,
    required List<Map<String, dynamic>> records,
    required bool hasUpdatedAt,
    required int? lastSyncMs,
    required Set<String> pendingRecordIds,
    required Map<String, Map<String, int>> allTombstones,
    required Map<String, Set<String>> revivedParents,
  }) async {
    if (records.isEmpty) {
      return const _MergeResult(recordsApplied: 0, conflictsFound: 0);
    }

    var applied = 0;
    var conflicts = 0;
    var failed = 0;

    final selfTombstones = allTombstones[entityType] ?? const <String, int>{};
    final entityParentRefs = parentRefs[entityType] ?? const <ParentRef>[];

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

        // Parent-deletion guard: a record pointing at a locally-tombstoned
        // parent would otherwise dangle its FK (failing the deferred-FK commit)
        // or resurrect an orphan. A NOT NULL (cascade) child is skipped; a
        // nullable (set-null) reference is cleared so the row survives detached
        // (e.g. a photo whose dive was deleted keeps the photo, sans dive link).
        var recordToApply = record;
        var droppedByParent = false;
        for (final ref in entityParentRefs) {
          final parentId = record[ref.field];
          if (parentId is String &&
              (allTombstones[ref.parent]?.containsKey(parentId) ?? false) &&
              // A parent being revived in this same payload is NOT gone; keep
              // the child's reference intact regardless of merge order.
              (revivedParents[ref.parent]?.contains(parentId) != true)) {
            if (ref.nullable) {
              recordToApply = {...recordToApply, ref.field: null};
            } else {
              droppedByParent = true;
              break;
            }
          }
        }
        if (droppedByParent) continue;

        // Local-deletion guard: if we deleted this record, a remote LIVE copy
        // must not resurrect it unless the remote edit is newer than our
        // deletion (a genuine revival). Without this, a peer that has not yet
        // seen our delete re-introduces the record on every sync.
        final deletedAt = selfTombstones[recordId];
        if (deletedAt != null) {
          final remoteUpdatedAt = hasUpdatedAt
              ? _extractUpdatedAtMillis(record)
              : null;
          if (remoteUpdatedAt == null || remoteUpdatedAt <= deletedAt) {
            // No newer remote edit -- the deletion wins; stay deleted.
            continue;
          }
          // Remote edit is newer than the deletion: revive the record and drop
          // the now-obsolete tombstone so it stops re-deleting it.
          await _syncRepository.removeDeletion(
            entityType: entityType,
            recordId: recordId,
          );
        }

        if (!hasUpdatedAt) {
          await _serializer.upsertRecord(entityType, recordToApply);
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
            await _serializer.upsertRecord(entityType, recordToApply);
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
          await _serializer.upsertRecord(entityType, recordToApply);
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

  /// Local deletion tombstones as entityType -> (recordId -> latest deletedAt).
  /// Used by [_mergeEntity] to keep a remote live copy from resurrecting a
  /// record we have deleted.
  Future<Map<String, Map<String, int>>> _deletionMap() async {
    final deletions = await _syncRepository.getAllDeletions();
    final map = <String, Map<String, int>>{};
    for (final d in deletions) {
      final byId = map.putIfAbsent(d.entityType, () => <String, int>{});
      final existing = byId[d.recordId];
      // Keep the most recent deletion if duplicate tombstones exist.
      if (existing == null || d.deletedAt > existing) {
        byId[d.recordId] = d.deletedAt;
      }
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

  /// Reset sync state (for debugging or account changes).
  ///
  /// Keeps the deletion log: this reset is the user-facing recovery path,
  /// and the next sync after it runs with a null baseline, where a wiped
  /// log would let stale peer files resurrect every deleted record.
  Future<void> resetSyncState() async {
    await _syncRepository.resetSyncState(clearDeletionLog: false);
    _log.info('Sync state reset');
  }

  /// Best-effort removal of [deviceId]'s per-device sync file from the
  /// cloud. Used when this install retires an identity (Reset Sync State):
  /// once the device id changes, its old file would otherwise be merged
  /// back as a "peer" forever. Never throws; if the provider is offline the
  /// file lingers indefinitely as a stale peer.
  Future<void> deleteDeviceSyncFile(String deviceId) async {
    final provider = _cloudProvider;
    if (provider == null) return;
    try {
      final filename = _deviceSyncFileName(deviceId);
      final files = await provider
          .listFiles(namePattern: CloudStorageProviderMixin.syncFileStem)
          .timeout(const Duration(seconds: 8));
      for (final f in files) {
        if (f.name == filename) {
          await provider.deleteFile(f.id).timeout(const Duration(seconds: 8));
          _log.info('Retired per-device sync file $filename');
        }
      }
    } catch (e) {
      _log.warning('Could not retire sync file for $deviceId: $e');
    }
  }

  /// Download and parse the cloud epoch marker. Returns null when absent.
  /// Throws on listing/parse failure: "unreadable" must be distinguishable
  /// from "absent" -- the caller fails the sync closed rather than guessing.
  Future<LibraryEpochMarker?> readLibraryEpochMarker(
    CloudStorageProvider provider,
  ) async {
    final files = await provider
        .listFiles(namePattern: libraryEpochFileName)
        .timeout(const Duration(seconds: 8));
    final candidates = files
        .where((f) => !_isConflictCopy(f.name))
        .where((f) => f.name == libraryEpochFileName)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    final bytes = await provider
        .downloadFile(candidates.first.id)
        .timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Library epoch marker is not a JSON object');
    }
    return LibraryEpochMarker.fromJson(decoded);
  }

  /// Upload (or overwrite) the cloud epoch marker.
  Future<void> writeLibraryEpochMarker(
    CloudStorageProvider provider,
    LibraryEpochMarker marker,
  ) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(marker.toJson())));
    String? folderId;
    try {
      folderId = await provider.getOrCreateSyncFolder();
    } catch (_) {
      folderId = null;
    }
    await provider
        .uploadFile(bytes, libraryEpochFileName, folderId: folderId)
        .timeout(const Duration(seconds: 60));
    _log.info('Wrote library epoch marker ${marker.epochId}');
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
