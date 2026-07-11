import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart'
    show SyncRecord, DeletionLogData;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/changeset_log/base_json_stream_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/base_parse_client.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_sink.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/stale_restore_detector.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/library_moved.dart';
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
  awaitingAdoption,
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

  /// Set with [SyncResultStatus.awaitingAdoption]: the cloud library was
  /// replaced under this marker's epoch and the user must adopt (or defer)
  /// before any sync can proceed.
  final LibraryEpochMarker? replaceMarker;

  const SyncResult({
    required this.status,
    this.message,
    this.recordsSynced = 0,
    this.conflictsFound = 0,
    this.lastSyncTime,
    this.adoptedFreshIdentity = false,
    this.replaceMarker,
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

/// Outcome of the library-epoch gate: either a [terminal] result the caller
/// must return immediately (a pending replace was executed, the marker was
/// unreadable, or the cloud library was replaced and awaits adoption), or the
/// resolved [currentEpochId] to stamp and filter by for the rest of the sync
/// (null in the pre-epoch world).
class _EpochGate {
  const _EpochGate.proceed(this.currentEpochId) : terminal = null;
  const _EpochGate.halt(this.terminal) : currentEpochId = null;
  final String? currentEpochId;
  final SyncResult? terminal;
}

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

  /// How long a library-epoch marker with no readable (ssv1) library may exist
  /// before it is treated as orphaned (a replace that never landed) rather than
  /// in flight. A backend carrying only old-format files is recovered
  /// immediately, regardless of this.
  static const _unreadableEpochGraceMs = 60 * 60 * 1000; // 1 hour

  // Changeset-log transport (Phases 1-6), lazily bound to the active database.
  late final ChangesetCodec _changesetCodec = ChangesetCodec(_serializer);

  /// Assembles a peer's base parts into a temp file (per-part + whole-file
  /// checksum verified) for the bounded-memory replace-adopt (#358).
  final BasePartFileSink _baseSink = BasePartFileSink();
  late final PublishStateStore _publishStateStore = PublishStateStore(
    DatabaseService.instance.database,
  );
  late final ChangesetWriter _changesetWriter = ChangesetWriter(
    _serializer,
    _changesetCodec,
    _publishStateStore,
  );
  late final ChangesetReader _changesetReader = ChangesetReader(
    _changesetCodec,
    PeerCursorStore(DatabaseService.instance.database),
  );
  late final StaleRestoreDetector _staleRestoreDetector = StaleRestoreDetector(
    _syncRepository,
  );

  SyncProgressCallback? _progressCallback;

  /// Test seam: how the base apply spawns its parse worker. Overridable so a
  /// forced-failure test can verify the inline fallback; production uses the
  /// real isolate spawn.
  @visibleForTesting
  Future<BaseParseClient> Function(String filePath) baseParseClientSpawn =
      BaseParseClient.spawn;

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

  /// Test seam: apply an in-memory payload through the standard merge. Exposed
  /// so the streaming-vs-in-memory parity test can compare apply paths.
  @visibleForTesting
  Future<({int recordsApplied, int conflictsFound, int recordsFailed})>
  debugApplyPayload(SyncPayload payload, {DateTime? lastSync}) async {
    final r = await _applyRemotePayload(payload, lastSync);
    return (
      recordsApplied: r.recordsApplied,
      conflictsFound: r.conflictsFound,
      recordsFailed: r.recordsFailed,
    );
  }

  /// Test seam: apply a base from a local file through the streaming merge.
  @visibleForTesting
  Future<({int recordsApplied, int conflictsFound, int recordsFailed})>
  debugApplyBaseFile(String filePath, {DateTime? lastSync}) async {
    final r = await _applyRemoteBaseFile(filePath, lastSync);
    return (
      recordsApplied: r.recordsApplied,
      conflictsFound: r.conflictsFound,
      recordsFailed: r.recordsFailed,
    );
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

  /// Incremental changeset-log sync: the live sync path. Pulls peers' deltas
  /// through the existing HLC/LWW merge, then publishes this device's own
  /// delta, with the library-epoch gate and twin-identity split folded in.
  ///
  /// Pipeline: auth -> epoch gate -> twin split -> stale-restore reset ->
  /// pull peers (epoch-filtered) -> publish our delta (epoch-stamped) ->
  /// advance state. Re-pulls are idempotent (upsert + HLC), so a partial apply
  /// leaves state unadvanced and retries next sync rather than losing records.
  Future<SyncResult> performSync() async {
    final provider = _cloudProvider;
    if (provider == null) {
      return const SyncResult(
        status: SyncResultStatus.error,
        message: 'No cloud provider configured',
      );
    }
    try {
      _reportProgress(SyncPhase.preparing, 0.0, 'Preparing sync...');
      if (!await provider.isAuthenticated()) {
        return const SyncResult(
          status: SyncResultStatus.authError,
          message: 'Not authenticated with cloud provider',
        );
      }
      var deviceId = await _syncRepository.getDeviceId();
      // Scoped to this provider: a cursor minted against a backend we switched
      // away from reads as null here, forcing a full cold-start reconcile on
      // the new backend rather than replaying a foreign baseline.
      final lastSyncTime = await _syncRepository.getLastSyncTime(
        forProvider: provider.providerId,
      );
      await _syncRepository.ensureSyncClockConfigured();

      // ---- Library epoch gate (restore Replace mode) ----
      // A pending replace runs INSTEAD of a merge, and a marker from an
      // unaccepted epoch halts everything until the user adopts.
      final gate = await _runEpochGate(provider);
      if (gate.terminal != null) return gate.terminal!;
      final currentEpochId = gate.currentEpochId;

      final folderId = await provider.getOrCreateSyncFolder();

      // ---- Twin-identity split ----
      // Our own cloud manifest carrying a nonce we never minted means another
      // install is syncing as this device (a whole-container OS clone). Adopt a
      // fresh identity now; the old id's files then read as a peer below and
      // the twins converge in this same sync.
      final twin = await _detectTwin(provider, deviceId, folderId);
      deviceId = twin.deviceId;
      final adoptedFreshIdentity = twin.adopted;

      // ---- Stale-restore: cold-start to re-pull the authoritative library ----
      if (await _staleRestoreDetector.isStaleRestore(
        provider: provider,
        deviceId: deviceId,
        folderId: folderId,
      )) {
        _log.warning('Stale restore detected; resetting changeset cursors');
        final db = DatabaseService.instance.database;
        await PeerCursorStore(db).resetForProvider(provider.providerId);
        await PublishStateStore(db).resetForProvider(provider.providerId);
        // NOTE: deliberately do NOT clear the deletion log here. This detector
        // is a coarse backstop that also fires when the user legitimately
        // deletes their last HLC-bearing row (local max HLC drops below the
        // published watermark with no actual restore). Wiping tombstones then
        // would let a peer's stale live copy resurrect a just-deleted record.
        // Stale-tombstone safety is already handled by the merge's deletedAt-vs-
        // updatedAt LWW, so no clear is needed (or safe) here.
      }

      // ---- Download: pull peers, applying through the existing merge ----
      _reportProgress(SyncPhase.downloading, 0.4, 'Pulling changes...');
      var recordsSynced = 0;
      var conflictsFound = 0;
      var recordsFailed = 0;
      await _changesetReader.pull(
        provider: provider,
        selfDeviceId: deviceId,
        folderId: folderId,
        currentEpochId: currentEpochId,
        apply: (payload) async {
          final r = await _applyRemotePayload(payload, lastSyncTime);
          recordsSynced += r.recordsApplied;
          conflictsFound += r.conflictsFound;
          recordsFailed += r.recordsFailed;
        },
        applyBaseFile: (path, manifest) async {
          final r = await _applyRemoteBaseFile(path, lastSyncTime);
          recordsSynced += r.recordsApplied;
          conflictsFound += r.conflictsFound;
          recordsFailed += r.recordsFailed;
        },
      );

      // ---- Upload: publish our delta ----
      _reportProgress(SyncPhase.uploading, 0.8, 'Publishing changes...');
      final deletions = await _syncRepository.getAllDeletions();
      var publishAttempted = false;
      if (await _shouldSkipPublishAfterAdopt(provider.providerId, deletions)) {
        // Just adopted a restored library and have nothing of our own yet: our
        // library == the adopted epoch the peers already published, so there
        // is nothing to say. Skip the publish entirely (checked before the
        // nonce so a skipped sync does not consume a nonce ring slot). Once a
        // local change exists, the writer publishes it as a small changeset
        // against the adopted watermark -- never a redundant full base (#358).
        _log.info('Skipping publish after adopt (no local changes yet)');
      } else {
        publishAttempted = true;
        final uploadNonce = _uuid.v4();
        // Record the nonce BEFORE publishing: a lost response (timeout, app
        // death) still leaves our manifest carrying this nonce, and an
        // unrecorded copy would read as a foreign twin on the next sync.
        await _syncInitializer?.recordUploadNonce(
          uploadNonce,
          provider.providerId,
        );
        try {
          await _changesetWriter.publish(
            provider: provider,
            deviceId: deviceId,
            folderId: folderId,
            deletions: deletions,
            epochId: currentEpochId,
            uploadNonce: uploadNonce,
          );
        } catch (e) {
          // Keep the speculative nonce on a timeout (the publish may have
          // landed); remove it only on definite failures, so repeated hard
          // failures cannot evict the last good nonce from the ring.
          final cause = e is SyncStepException ? e.error : e;
          if (cause is! TimeoutException) {
            await _syncInitializer?.removeUploadNonce(
              uploadNonce,
              provider.providerId,
            );
          }
          rethrow;
        }
      }

      // Advance state only on a clean apply (idempotent re-pull otherwise).
      final now = DateTime.now();
      if (recordsFailed == 0) {
        await _syncRepository.updateLastSyncTime(
          now,
          providerId: provider.providerId,
        );
      }
      await _syncRepository.persistSyncClock();
      await _syncRepository.clearOldDeletions();
      // Clear upload-side bookkeeping only when a publish actually ran. On a
      // skipped (post-adopt, nothing-to-say) sync, an edit can land between
      // the skip decision and this cleanup; wiping its pending row here would
      // make every following sync skip again and the edit would never publish
      // until some unrelated later edit re-tripped the gate.
      if (publishAttempted) {
        await _syncRepository.clearPendingRecords();
        if (conflictsFound == 0) {
          await _syncRepository.clearAllSyncRecords();
        }
      }

      _reportProgress(SyncPhase.complete, 1.0, 'Sync complete');
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
        lastSyncTime: recordsFailed == 0 ? now : null,
        adoptedFreshIdentity: adoptedFreshIdentity,
      );
    } on TimeoutException {
      _log.warning('Sync timed out');
      return const SyncResult(
        status: SyncResultStatus.networkError,
        message: 'Sync timed out',
      );
    } on CloudStorageException catch (e) {
      return SyncResult(
        status: SyncResultStatus.networkError,
        message: e.message,
      );
    } catch (e, stackTrace) {
      _log.error('Changeset sync failed', error: e, stackTrace: stackTrace);
      return SyncResult(
        status: SyncResultStatus.error,
        message: _formatSyncError(e, stackTrace),
      );
    }
  }

  /// Run the library-epoch gate. Returns a terminal result the caller must
  /// return immediately, or the resolved currentEpochId to proceed with.
  /// Mirrors the inline gate the legacy full-file performSync used.
  Future<_EpochGate> _runEpochGate(CloudStorageProvider provider) async {
    final epochStore = _epochStore;
    if (epochStore == null) return const _EpochGate.proceed(null);

    final pending = epochStore.pendingReplace;
    if (pending != null) {
      return _EpochGate.halt(await executeLibraryReplace(pending));
    }
    final accepted =
        await _syncRepository.getLastAcceptedEpochId() ??
        epochStore.lastAcceptedEpochId;
    LibraryEpochMarker? marker;
    try {
      marker = await readLibraryEpochMarker(provider);
    } catch (e) {
      _log.warning('Library epoch marker unreadable; failing closed: $e');
      return const _EpochGate.halt(
        SyncResult(
          status: SyncResultStatus.error,
          message: 'Could not read the library epoch marker',
        ),
      );
    }
    if (marker == null) {
      if (accepted != null) {
        // On an epoch but the marker vanished: self-heal it from the mirror
        // and continue as current.
        final stored = epochStore.lastAcceptedMarker;
        if (stored != null) {
          try {
            await writeLibraryEpochMarker(provider, stored);
          } catch (e) {
            _log.warning('Could not self-heal epoch marker: $e');
          }
        }
        return _EpochGate.proceed(accepted);
      }
      return const _EpochGate.proceed(null); // pre-epoch world
    }
    if (marker.epochId == accepted) {
      return _EpochGate.proceed(accepted);
    }
    // Before halting for adoption, make sure the marked library is actually
    // readable. A marker with no current-format (ssv1) library is either a
    // replace still in flight (wait) or orphaned / old-format (unrecoverable);
    // for the latter, re-establish this backend from our own library instead
    // of bricking sync in an un-adoptable awaiting-adoption loop.
    if (await _recoverUnreadableEpoch(provider, marker)) {
      return _EpochGate.proceed(marker.epochId);
    }
    _log.info(
      'Cloud library was replaced (epoch ${marker.epochId}); '
      'halting sync until the user adopts',
    );
    return _EpochGate.halt(
      SyncResult(
        status: SyncResultStatus.awaitingAdoption,
        message: 'The cloud library was replaced from a backup',
        replaceMarker: marker,
      ),
    );
  }

  /// When [marker]'s epoch has no readable (current-format) library, decide
  /// whether to recover or to wait. Recovery -- re-establish this backend from
  /// the local library (wipe stale files, cold-start the publish state, adopt
  /// the epoch) -- happens when the backend holds only old-format files (a
  /// pre-changeset app version) or the marker is older than the grace window (a
  /// replace whose base never landed). Returns true when it recovered; false to
  /// wait (a replace in flight) or when the library is adoptable. The caller
  /// then publishes (in performSync, or the notifier's follow-up sync after
  /// adopt), writing our library as the new base stamped with this epoch.
  Future<bool> _recoverUnreadableEpoch(
    CloudStorageProvider provider,
    LibraryEpochMarker marker,
  ) async {
    final epochStore = _epochStore;
    if (epochStore == null) return false;
    final folderId = await provider.getOrCreateSyncFolder();
    if (await _epochHasReadableLibrary(provider, folderId, marker.epochId)) {
      return false; // adoptable -> caller halts for adoption
    }
    final legacy = await provider.listFiles(
      namePattern: CloudStorageProviderMixin.syncFileStem,
    );
    final ageMs = DateTime.now().millisecondsSinceEpoch - marker.replacedAt;
    if (legacy.isEmpty && ageMs <= _unreadableEpochGraceMs) {
      return false; // possibly a replace in flight -> wait
    }
    _log.warning(
      'Epoch ${marker.epochId} has no readable library; re-establishing this '
      'backend from the local library',
    );
    await _reestablishEpochFromLocalLibrary(provider, marker);
    return true;
  }

  /// Make THIS device's library the authoritative base for [marker]'s epoch:
  /// wipe the (unreadable/incomplete) sync files, drop this backend's publish
  /// and peer state so the next sync republishes a full base, and accept the
  /// epoch locally. Shared by the automatic unreadable-epoch recovery and the
  /// user-driven [rebuildBackendFromThisDevice].
  Future<void> _reestablishEpochFromLocalLibrary(
    CloudStorageProvider provider,
    LibraryEpochMarker marker,
  ) async {
    await deleteAllSyncFiles(provider);
    final db = DatabaseService.instance.database;
    await PublishStateStore(db).resetForProvider(provider.providerId);
    await PeerCursorStore(db).resetForProvider(provider.providerId);
    await _syncRepository.setLastAcceptedEpochId(marker.epochId);
    await _epochStore?.setLastAccepted(marker);
  }

  /// User-driven escape from a stuck library replacement (issue #509): the
  /// device that ran "Replace everywhere" went offline before uploading the new
  /// base, so every other device waits forever on "still uploading". This
  /// forces the re-establish that [_recoverUnreadableEpoch] defers during its
  /// grace window: THIS device's library becomes the epoch's authoritative
  /// base, and the caller's follow-up sync publishes it. Peers then adopt from
  /// us instead of the offline device.
  Future<SyncResult> rebuildBackendFromThisDevice() async {
    final provider = _cloudProvider;
    if (provider == null) {
      return const SyncResult(
        status: SyncResultStatus.error,
        message: 'No cloud provider configured',
      );
    }
    final marker = await readLibraryEpochMarker(provider);
    if (marker == null) {
      return const SyncResult(
        status: SyncResultStatus.error,
        message: 'No library replacement to rebuild from',
      );
    }
    try {
      await _reestablishEpochFromLocalLibrary(provider, marker);
      _log.info('Rebuilt backend from this device for epoch ${marker.epochId}');
      return const SyncResult(
        status: SyncResultStatus.success,
        message: 'Rebuilt this backend from this device’s library',
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to rebuild backend from this device',
        error: e,
        stackTrace: stackTrace,
      );
      return SyncResult(
        status: SyncResultStatus.error,
        message: 'Rebuild failed: $e',
      );
    }
  }

  /// True if any device has published a current-format (ssv1) base for
  /// [epochId] -- i.e. the marked library is actually adoptable.
  Future<bool> _epochHasReadableLibrary(
    CloudStorageProvider provider,
    String folderId,
    String epochId,
  ) async {
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: ChangesetLogLayout.prefix,
    );
    for (final f in files) {
      if (!ChangesetLogLayout.isManifest(f.name)) continue;
      try {
        final m = SyncManifest.fromBytes(await provider.downloadFile(f.id));
        if (m.epochId == epochId && m.baseSeq != null) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Twin-identity split: if this device's own cloud manifest carries an
  /// upload nonce we never minted, another install is syncing as us. Adopt a
  /// fresh identity and re-seed the clock; the returned id is used for the rest
  /// of the sync so the old id's files merge as a peer and the twins converge.
  Future<({String deviceId, bool adopted})> _detectTwin(
    CloudStorageProvider provider,
    String deviceId,
    String folderId,
  ) async {
    final initializer = _syncInitializer;
    if (initializer == null) return (deviceId: deviceId, adopted: false);
    final manifest = await _readManifest(provider, folderId, deviceId);
    final nonce = manifest?.uploadNonce;
    // Require the manifest to actually claim our id: a manifest at our filename
    // whose body names a different device is mislabeled, not evidence that
    // another install is syncing as us.
    if (manifest == null ||
        manifest.deviceId != deviceId ||
        nonce == null ||
        !initializer.isForeignUploadNonce(nonce, provider.providerId)) {
      return (deviceId: deviceId, adopted: false);
    }
    _log.warning(
      'Another install is uploading as this device id; adopting a fresh '
      'sync identity to split the twins',
    );
    final newId = await initializer.adoptFreshIdentity();
    // Re-seed the HLC clock under the new node id so remote HLCs received while
    // merging the converging files advance it instead of no-opping.
    await _syncRepository.ensureSyncClockConfigured();
    return (deviceId: newId, adopted: true);
  }

  /// Read a device's own changeset manifest from the cloud, or null if absent
  /// or unparseable.
  Future<SyncManifest?> _readManifest(
    CloudStorageProvider provider,
    String folderId,
    String deviceId,
  ) async {
    final name = ChangesetLogLayout.manifestName(deviceId);
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: ChangesetLogLayout.prefix,
    );
    final match = files.where((f) => f.name == name).firstOrNull;
    if (match == null) return null;
    try {
      return SyncManifest.fromBytes(await provider.downloadFile(match.id));
    } catch (_) {
      return null;
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

    // A payload can present a record as LIVE and ALSO carry a tombstone for the
    // same key -- the on-the-wire signature of a composite-natural-key junction
    // (equipment_set_items, dive_equipment) rebuilt by its repository via
    // delete-all-then-reinsert. A row cannot be both present and deleted in one
    // source snapshot, so the live table is authoritative and the tombstone is
    // a stale artifact. Collect these self-contradicted keys: the deletion is
    // skipped below and the live row wins (clearing any local tombstone in the
    // merge heals a peer that already dropped the row on the buggy build).
    final contradictedByEntity = <String, Set<String>>{};
    final liveByType = remotePayload.data.toJson();
    for (final delEntry in remotePayload.deletions.entries) {
      final deletedIds = {for (final d in delEntry.value) d.id};
      if (deletedIds.isEmpty) continue;
      final live = liveByType[delEntry.key];
      if (live is! List) continue;
      final contradicted = <String>{};
      for (final rec in live) {
        if (rec is! Map<String, dynamic>) continue;
        final id = _recordIdForEntity(delEntry.key, rec);
        if (id != null && deletedIds.contains(id)) contradicted.add(id);
      }
      if (contradicted.isNotEmpty) {
        contradictedByEntity[delEntry.key] = contradicted;
      }
    }

    final deletionResult = await _applyRemoteDeletions(
      remotePayload.deletions,
      lastSyncMs,
      remotePayload.exportedAt,
      pendingByEntity,
      contradictedByEntity,
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
          (type: 'buddyRoles', records: data.buddyRoles, hasUpdatedAt: true),
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
          (
            type: 'checklistTemplates',
            records: data.checklistTemplates,
            hasUpdatedAt: true,
          ),
          (
            type: 'checklistTemplateItems',
            records: data.checklistTemplateItems,
            hasUpdatedAt: true,
          ),
          (
            type: 'tripChecklistItems',
            records: data.tripChecklistItems,
            hasUpdatedAt: true,
          ),
          (type: 'gpsTracks', records: data.gpsTracks, hasUpdatedAt: true),
          (type: 'divePlans', records: data.divePlans, hasUpdatedAt: true),
          (
            type: 'divePlanTanks',
            records: data.divePlanTanks,
            hasUpdatedAt: true,
          ),
          (
            type: 'divePlanSegments',
            records: data.divePlanSegments,
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
          (type: 'diveRoles', records: data.diveRoles, hasUpdatedAt: true),
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
          (
            type: 'diveDiveTypes',
            records: data.diveDiveTypes,
            hasUpdatedAt: false,
          ),
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
        contradicted: contradictedByEntity[entry.type] ?? const <String>{},
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

  /// Apply a base that was streamed to a local temp [filePath], in bounded
  /// memory. Three forward passes over the file:
  ///   1. header `exportedAt` + the full `deletions` map (both small),
  ///   2. parent-row id->updatedAt and contradiction keys (skips giant tables),
  ///   3. batched apply of every row through the existing [_mergeEntity].
  /// Applies a peer's base file. Tries the worker-isolate path (file read +
  /// JSON parse off the UI isolate; the whole-file SHA-256 still runs on the
  /// main isolate in BasePartFileSink.assemble -- folding it in is a deferred
  /// follow-up) and falls back to the inline path on any worker failure, so a
  /// broken isolate degrades to old behaviour and never fails or corrupts sync.
  Future<_MergeResult> _applyRemoteBaseFile(
    String filePath,
    DateTime? localLastSync,
  ) async {
    BaseParseClient? client;
    try {
      client = await baseParseClientSpawn(filePath);
      return await _applyRemoteBaseFileViaWorker(client, localLastSync);
    } catch (e, st) {
      _log.warning(
        'Base-apply worker failed; falling back to inline',
        error: e,
        stackTrace: st,
      );
      return _applyRemoteBaseFileInline(filePath, localLastSync);
    } finally {
      await client?.dispose();
    }
  }

  /// Worker-backed base apply: the file read + JSON parse run in [client]'s
  /// isolate; the merge/writes (and, for now, the whole-file SHA-256 in
  /// BasePartFileSink.assemble) run here. Mirrors [_applyRemoteBaseFileInline]
  /// exactly, fed by streamed rows in file order instead of an inline parse (so
  /// per-table batching and mergeOrder match).
  Future<_MergeResult> _applyRemoteBaseFileViaWorker(
    BaseParseClient client,
    DateTime? localLastSync,
  ) async {
    final lastSyncMs = localLastSync?.millisecondsSinceEpoch;

    // ---- Pass 1: exportedAt + deletions ----
    final p1 = await client.readScalarsAndDeletions();
    final baseExportedAt = p1.exportedAt;
    final deletions = <String, List<SyncDeletion>>{};
    for (final e in p1.deletions) {
      (deletions[e.table] ??= []).add(SyncDeletion.fromJson(e.row));
    }

    final pendingByEntity = await _pendingRecordMap();

    // ---- Pass 2: parent updatedAt + contradiction keys ----
    final parentTypes = <String>{
      for (final refs in parentRefs.values)
        for (final ref in refs) ref.parent,
    };
    final deletionIds = <String, Set<String>>{
      for (final e in deletions.entries) e.key: {for (final d in e.value) d.id},
    };
    final parentUpdatedAt = <String, Map<String, int>>{};
    final contradictedByEntity = <String, Set<String>>{};
    final pass2Tables = <String>{
      for (final table in entityHasUpdatedAt.keys)
        if (parentTypes.contains(table) || deletionIds.containsKey(table))
          table,
    };
    client.startDataRows(pass2Tables);
    List<({String table, Map<String, dynamic> row})>? p2batch;
    while ((p2batch = await client.nextDataBatch()) != null) {
      for (final r in p2batch!) {
        final table = r.table;
        final rec = r.row;
        final id = _recordIdForEntity(table, rec);
        if (id == null) continue;
        if (parentTypes.contains(table) && entityHasUpdatedAt[table] == true) {
          final u = _extractUpdatedAtMillis(rec);
          if (u != null) (parentUpdatedAt[table] ??= {})[id] = u;
        }
        if (deletionIds[table]?.contains(id) == true) {
          (contradictedByEntity[table] ??= {}).add(id);
        }
      }
    }

    // ---- Apply, all inside one deferred-FK transaction ----
    return _serializer.applyInDeferredFkTransaction(() async {
      var recordsApplied = 0;
      var conflictsFound = 0;
      var recordsFailed = 0;

      final delResult = await _applyRemoteDeletions(
        deletions,
        lastSyncMs,
        baseExportedAt,
        pendingByEntity,
        contradictedByEntity,
      );
      recordsApplied += delResult.recordsApplied;
      conflictsFound += delResult.conflictsFound;
      recordsFailed += delResult.recordsFailed;

      final tombstonesByEntity = await _deletionMap();

      final revivedParents = <String, Set<String>>{};
      for (final parentType in parentTypes) {
        final tombs = tombstonesByEntity[parentType];
        final ups = parentUpdatedAt[parentType];
        if (tombs == null || tombs.isEmpty || ups == null) continue;
        ups.forEach((id, updatedAt) {
          final deletedAt = tombs[id];
          if (deletedAt != null && updatedAt > deletedAt) {
            (revivedParents[parentType] ??= {}).add(id);
          }
        });
      }

      // ---- Pass 3: batched apply ----
      const batchSize = 500;
      String? currentTable;
      var batch = <Map<String, dynamic>>[];

      Future<void> flush() async {
        final table = currentTable;
        if (table == null || batch.isEmpty) return;
        final r = await _mergeEntity(
          entityType: table,
          records: batch,
          hasUpdatedAt: entityHasUpdatedAt[table] ?? false,
          lastSyncMs: lastSyncMs,
          pendingRecordIds: pendingByEntity[table] ?? const <String>{},
          allTombstones: tombstonesByEntity,
          revivedParents: revivedParents,
          contradicted: contradictedByEntity[table] ?? const <String>{},
        );
        recordsApplied += r.recordsApplied;
        conflictsFound += r.conflictsFound;
        recordsFailed += r.recordsFailed;
        batch = <Map<String, dynamic>>[];
      }

      client.startDataRows(entityHasUpdatedAt.keys.toSet());
      List<({String table, Map<String, dynamic> row})>? p3batch;
      while ((p3batch = await client.nextDataBatch()) != null) {
        for (final r in p3batch!) {
          if (r.table != currentTable) {
            await flush();
            currentTable = r.table;
          }
          batch.add(r.row);
          if (batch.length >= batchSize) await flush();
        }
      }
      await flush();

      await _serializer.repairDanglingForeignKeys();
      return _MergeResult(
        recordsApplied: recordsApplied,
        conflictsFound: conflictsFound,
        recordsFailed: recordsFailed,
      );
    });
  }

  /// Reuses the same merge primitives as [_applyRemotePayloadInner], so the
  /// result is identical to applying the equivalent in-memory payload, but peak
  /// memory stays at one ~8 MB part download + one batch of rows regardless of
  /// library size (issue #358).
  Future<_MergeResult> _applyRemoteBaseFileInline(
    String filePath,
    DateTime? localLastSync,
  ) async {
    final file = File(filePath);
    final lastSyncMs = localLastSync?.millisecondsSinceEpoch;

    // ---- Pass 1: exportedAt + deletions ----
    var baseExportedAt = 0;
    final deletions = <String, List<SyncDeletion>>{};
    await BaseJsonStreamReader().parse(
      file.openRead(),
      onScalar: (key, raw) async {
        if (key == 'exportedAt') {
          baseExportedAt = (jsonDecode(utf8.decode(raw)) as num?)?.toInt() ?? 0;
        }
      },
      wantRows: (section, _) => section == 'deletions',
      onRow: (section, table, rowBytes) async {
        final decoded = jsonDecode(utf8.decode(rowBytes));
        if (decoded is Map<String, dynamic>) {
          (deletions[table] ??= []).add(SyncDeletion.fromJson(decoded));
        } else if (decoded is Map) {
          (deletions[table] ??= []).add(
            SyncDeletion.fromJson(decoded.cast<String, dynamic>()),
          );
        } else if (decoded is String) {
          (deletions[table] ??= []).add(
            SyncDeletion(id: decoded, deletedAt: 0),
          );
        }
      },
    );

    final pendingByEntity = await _pendingRecordMap();

    // ---- Pass 2: parent updatedAt + contradiction keys ----
    final parentTypes = <String>{
      for (final refs in parentRefs.values)
        for (final ref in refs) ref.parent,
    };
    final deletionIds = <String, Set<String>>{
      for (final e in deletions.entries) e.key: {for (final d in e.value) d.id},
    };
    final parentUpdatedAt = <String, Map<String, int>>{};
    final contradictedByEntity = <String, Set<String>>{};
    await BaseJsonStreamReader().parse(
      file.openRead(),
      wantRows: (section, table) =>
          section == 'data' &&
          entityHasUpdatedAt.containsKey(table) &&
          (parentTypes.contains(table) || deletionIds.containsKey(table)),
      onRow: (section, table, rowBytes) async {
        final rec = jsonDecode(utf8.decode(rowBytes)) as Map<String, dynamic>;
        final id = _recordIdForEntity(table, rec);
        if (id == null) return;
        if (parentTypes.contains(table) && entityHasUpdatedAt[table] == true) {
          final u = _extractUpdatedAtMillis(rec);
          if (u != null) (parentUpdatedAt[table] ??= {})[id] = u;
        }
        if (deletionIds[table]?.contains(id) == true) {
          (contradictedByEntity[table] ??= {}).add(id);
        }
      },
    );

    // ---- Apply, all inside one deferred-FK transaction ----
    return _serializer.applyInDeferredFkTransaction(() async {
      var recordsApplied = 0;
      var conflictsFound = 0;
      var recordsFailed = 0;

      final delResult = await _applyRemoteDeletions(
        deletions,
        lastSyncMs,
        baseExportedAt,
        pendingByEntity,
        contradictedByEntity,
      );
      recordsApplied += delResult.recordsApplied;
      conflictsFound += delResult.conflictsFound;
      recordsFailed += delResult.recordsFailed;

      // Load tombstones AFTER deletions so a tombstone arriving in this base
      // also guards the merge below (mirrors _applyRemotePayloadInner).
      final tombstonesByEntity = await _deletionMap();

      // Revived parents: a parent row whose remote updatedAt is newer than our
      // local tombstone. Combines pass-2 file data with post-deletion
      // tombstones, so it is complete before any row is merged (a child may
      // precede its parent in file order).
      final revivedParents = <String, Set<String>>{};
      for (final parentType in parentTypes) {
        final tombs = tombstonesByEntity[parentType];
        final ups = parentUpdatedAt[parentType];
        if (tombs == null || tombs.isEmpty || ups == null) continue;
        ups.forEach((id, updatedAt) {
          final deletedAt = tombs[id];
          if (deletedAt != null && updatedAt > deletedAt) {
            (revivedParents[parentType] ??= {}).add(id);
          }
        });
      }

      // ---- Pass 3: batched apply ----
      const batchSize = 500;
      String? currentTable;
      var batch = <Map<String, dynamic>>[];

      Future<void> flush() async {
        final table = currentTable;
        if (table == null || batch.isEmpty) return;
        final r = await _mergeEntity(
          entityType: table,
          records: batch,
          hasUpdatedAt: entityHasUpdatedAt[table] ?? false,
          lastSyncMs: lastSyncMs,
          pendingRecordIds: pendingByEntity[table] ?? const <String>{},
          allTombstones: tombstonesByEntity,
          revivedParents: revivedParents,
          contradicted: contradictedByEntity[table] ?? const <String>{},
        );
        recordsApplied += r.recordsApplied;
        conflictsFound += r.conflictsFound;
        recordsFailed += r.recordsFailed;
        batch = <Map<String, dynamic>>[];
      }

      await BaseJsonStreamReader().parse(
        file.openRead(),
        wantRows: (section, table) =>
            section == 'data' && entityHasUpdatedAt.containsKey(table),
        onRow: (section, table, rowBytes) async {
          if (table != currentTable) {
            await flush();
            currentTable = table;
          }
          batch.add(jsonDecode(utf8.decode(rowBytes)) as Map<String, dynamic>);
          if (batch.length >= batchSize) await flush();
        },
      );
      await flush();

      await _serializer.repairDanglingForeignKeys();
      return _MergeResult(
        recordsApplied: recordsApplied,
        conflictsFound: conflictsFound,
        recordsFailed: recordsFailed,
      );
    });
  }

  Future<_MergeResult> _applyRemoteDeletions(
    Map<String, List<SyncDeletion>> deletions,
    int? lastSyncMs,
    int remoteExportedAt,
    Map<String, Set<String>> pendingByEntity,
    Map<String, Set<String>> contradictedByEntity,
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
          if (contradictedByEntity[entityType]?.contains(recordId) == true) {
            // The same payload re-inserts this row as live; the tombstone is a
            // stale delete-all+reinsert artifact. Skip it so the live row
            // survives (the merge upserts it and clears any local tombstone).
            continue;
          }
          final local = await _serializer.fetchRecord(entityType, recordId);
          // _extractUpdatedAtMillis falls back to createdAt, so a row created
          // locally after our last sync is protected from a stale remote
          // tombstone even on append-only child tables that have a createdAt.
          // Clockless child tables with neither updatedAt nor createdAt
          // (dive_profiles, dive_tanks, tank_pressure_profiles, sightings) have
          // no age signal: the uuid-keyed ones regenerate with fresh ids on
          // re-import, so a stale tombstone won't match a current row. The
          // composite-natural-key junctions (dive_equipment, equipment_set_items)
          // WOULD match a re-inserted row, but the contradicted-key skip above
          // already drops a tombstone whose key the same payload re-inserts.
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

  /// Per-entity "has an updatedAt column" flag, mirroring the `mergeOrder`
  /// records in [_applyRemotePayloadInner]. The streaming base apply
  /// ([_applyRemoteBaseFile]) uses it for (a) conflict-detection behavior in
  /// [_mergeEntity] and (b) the set of entity tables it applies (a table absent
  /// from these keys is silently skipped on base import).
  ///
  /// MUST list every [SyncData] entity: a structural test
  /// (`entityHasUpdatedAt covers exactly the SyncData entities`) asserts the
  /// keys match [SyncData], so adding an entity without a flag here fails that
  /// test. Each flag VALUE must match the `hasUpdatedAt` of the corresponding
  /// `mergeOrder` record above; the parity test verifies apply behavior for a
  /// representative subset (parent, clockless-child, junction, BLOB, and
  /// updatedAt tables plus a tombstone), not for every entity.
  @visibleForTesting
  static const Map<String, bool> entityHasUpdatedAt = {
    'divers': true,
    'diverSettings': true,
    'buddies': true,
    'buddyRoles': true,
    'diveCenters': true,
    'trips': true,
    'liveaboardDetails': true,
    'itineraryDays': true,
    'checklistTemplates': true,
    'checklistTemplateItems': true,
    'tripChecklistItems': true,
    'gpsTracks': true,
    'divePlans': true,
    'divePlanTanks': true,
    'divePlanSegments': true,
    'equipment': true,
    'equipmentSets': true,
    'equipmentSetItems': false,
    'diveTypes': true,
    'diveRoles': true,
    'tankPresets': true,
    'diveComputers': true,
    'species': false,
    'tags': true,
    'courses': true,
    'dives': true,
    'diveSites': true,
    'diveTanks': false,
    'diveWeights': false,
    'diveEquipment': false,
    'diveTags': false,
    'diveDiveTypes': false,
    'diveBuddies': false,
    'diveProfiles': false,
    'diveProfileEvents': false,
    'gasSwitches': false,
    'diveCustomFields': false,
    'diveDataSources': false,
    'siteSpecies': false,
    'csvPresets': true,
    'viewConfigs': true,
    'fieldPresets': false,
    'tankPressureProfiles': false,
    'tideRecords': false,
    'sightings': false,
    'certifications': true,
    'serviceRecords': true,
    'settings': true,
    'media': false,
  };

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
      (field: 'computerId', parent: 'diveComputers', nullable: true),
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
    'buddyRoles': [(field: 'buddyId', parent: 'buddies', nullable: false)],
    'diveTags': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'tagId', parent: 'tags', nullable: false),
    ],
    'diveDiveTypes': [(field: 'diveId', parent: 'dives', nullable: false)],
    'diveProfileEvents': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'computerId', parent: 'diveComputers', nullable: true),
    ],
    'gasSwitches': [(field: 'diveId', parent: 'dives', nullable: false)],
    'diveCustomFields': [(field: 'diveId', parent: 'dives', nullable: false)],
    'tankPressureProfiles': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'computerId', parent: 'diveComputers', nullable: true),
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
    'checklistTemplateItems': [
      (field: 'templateId', parent: 'checklistTemplates', nullable: false),
    ],
    'tripChecklistItems': [(field: 'tripId', parent: 'trips', nullable: false)],
    'divePlans': [
      (field: 'siteId', parent: 'diveSites', nullable: true),
      (field: 'sourceDiveId', parent: 'dives', nullable: true),
      (field: 'linkedDiveId', parent: 'dives', nullable: true),
    ],
    'divePlanTanks': [(field: 'planId', parent: 'divePlans', nullable: false)],
    'divePlanSegments': [
      (field: 'planId', parent: 'divePlans', nullable: false),
      (field: 'tankId', parent: 'divePlanTanks', nullable: false),
    ],
    'certifications': [
      (field: 'courseId', parent: 'courses', nullable: true),
      (field: 'instructorId', parent: 'buddies', nullable: true),
    ],
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
    required Set<String> contradicted,
  }) async {
    if (records.isEmpty) {
      return const _MergeResult(recordsApplied: 0, conflictsFound: 0);
    }

    var applied = 0;
    var conflicts = 0;
    var failed = 0;

    final selfTombstones = allTombstones[entityType] ?? const <String, int>{};
    final entityParentRefs = parentRefs[entityType] ?? const <ParentRef>[];

    // Read-decide-write: batch-fetch every local row the LWW compare needs in
    // one query (the clockless path needs no read). Each decision below reads
    // only this pre-fetched map plus the pre-fetched tombstone/pending maps --
    // never a row written earlier in this loop -- so deferring all writes to a
    // single batch at the end cannot change any decision.
    final localById = hasUpdatedAt
        ? await _serializer.fetchRecords(entityType, [
            for (final record in records)
              ?_recordIdForEntity(entityType, record),
          ])
        : const <String, Map<String, dynamic>>{};
    final toUpsert = <Map<String, dynamic>>[];

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
          if (contradicted.contains(recordId)) {
            // This same payload presents the record as live AND tombstones it
            // (a delete-all+reinsert artifact). The live row is the source's
            // current truth, so drop the stale tombstone -- including a local
            // one a prior buggy sync left behind -- and apply the record. This
            // is what self-heals a peer that already dropped the membership.
            await _syncRepository.removeDeletion(
              entityType: entityType,
              recordId: recordId,
            );
          } else {
            final remoteUpdatedAt = hasUpdatedAt
                ? _extractUpdatedAtMillis(record)
                : null;
            if (remoteUpdatedAt == null || remoteUpdatedAt <= deletedAt) {
              // No newer remote edit -- the deletion wins; stay deleted.
              continue;
            }
            // Remote edit is newer than the deletion: revive the record and
            // drop the now-obsolete tombstone so it stops re-deleting it.
            await _syncRepository.removeDeletion(
              entityType: entityType,
              recordId: recordId,
            );
          }
        }

        if (!hasUpdatedAt) {
          toUpsert.add(recordToApply);
          applied += 1;
          continue;
        }

        final local = localById[recordId];
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
            toUpsert.add(_overlayOntoLocal(recordToApply, local));
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
          toUpsert.add(_overlayOntoLocal(recordToApply, local));
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

    // Read-decide-write flush: one batched write for the whole merge-batch.
    // Drift's batch is all-or-nothing, so a failure fails every row it would
    // have applied -- move those from applied to failed, mirroring the per-row
    // catch above.
    if (toUpsert.isNotEmpty) {
      try {
        await _serializer.upsertRecords(entityType, toUpsert);
      } catch (e, stackTrace) {
        _log.error(
          'Failed to batch-upsert $entityType (${toUpsert.length} rows)',
          error: e,
          stackTrace: stackTrace,
        );
        failed += toUpsert.length;
        applied -= toUpsert.length;
      }
    }

    return _MergeResult(
      recordsApplied: applied,
      conflictsFound: conflicts,
      recordsFailed: failed,
    );
  }

  /// Overlays a winning remote row onto the receiver's current row so a column
  /// the remote payload OMITS keeps its local value, while every key the remote
  /// actually sends -- including an explicit `null` that clears a field (#474)
  /// -- wins. Rows are applied via `.toCompanion(false)` (so explicit nulls are
  /// written as SQL NULL); without this overlay that would also write NULL for
  /// every omitted column, silently clearing values a cross-version peer -- one
  /// predating a newly-added nullable column -- never intended to touch. Same-
  /// version peers export full rows, so the overlay is a no-op for them.
  static Map<String, dynamic> _overlayOntoLocal(
    Map<String, dynamic> remote,
    Map<String, dynamic>? local,
  ) => local == null ? remote : {...local, ...remote};

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
          // keepRemote overwrites the local row. For HLC-bearing entities the
          // upsert uses `.toCompanion(false)`, so a cross-version remote map
          // that OMITS a nullable key would write SQL NULL and clobber the
          // local value. Overlay onto the current local row first (mirrors
          // `_mergeEntity`): an omitted key keeps its local value, an explicit
          // null still clears. Clockless entities upsert with nullToAbsent, so
          // an omitted key is already preserved -- apply their map directly.
          final toApply = entityHasUpdatedAt[entityType] == true
              ? _overlayOntoLocal(
                  remoteData,
                  await _serializer.fetchRecord(entityType, recordId),
                )
              : remoteData;
          await _serializer.upsertRecord(entityType, toApply);
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

  /// Comprehensive local sync reset: everything [resetSyncState] clears, PLUS
  /// the SharedPreferences epoch markers (the one local sync state a DB reset
  /// misses -- see [LibraryEpochStore.clear]) and any leftover base temp files.
  /// A true reinstall-equivalent for sync state that never touches dive data.
  /// The notifier-level caller still runs the identity/cloud-file cleanup.
  Future<void> repairLocalSyncState() async {
    await resetSyncState();
    await _epochStore?.clear();
    await deleteLeftoverBaseTempFiles();
    _log.info('Local sync state repaired');
  }

  /// Best-effort sweep of leftover streaming-base temp files (base export
  /// base export `ssv1_base_*.json` and assembled `ssv1_*.base` / `ssv1_adopt_*`
  /// parts) from the app temp dir. Every sync temp file is prefixed `ssv1_`, so
  /// the sweep matches ONLY that prefix -- never an unrelated app temp file
  /// (the dir is a shared, general-purpose temp location). Failure is logged
  /// and ignored; a stale temp file is harmless.
  Future<void> deleteLeftoverBaseTempFiles() async {
    try {
      final dir = await resolveSyncTempDir();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('ssv1_')) {
          try {
            await entity.delete();
          } catch (_) {
            // best effort
          }
        }
      }
    } catch (e) {
      _log.warning('Could not sweep leftover base temp files: $e');
    }
  }

  /// Best-effort removal of [deviceId]'s entire changeset log from the cloud
  /// (manifest, base parts, changesets). Used when this install retires an
  /// identity (Reset Sync State): once the device id changes, its old log would
  /// otherwise be merged back as a stale "peer" forever. Never throws; if the
  /// provider is offline the log lingers indefinitely as a stale peer.
  Future<void> deleteDeviceSyncFile(String deviceId) async {
    final provider = _cloudProvider;
    if (provider == null) return;
    try {
      final files = await provider
          .listFiles(namePattern: ChangesetLogLayout.prefix)
          .timeout(const Duration(seconds: 8));
      for (final f in files) {
        if (ChangesetLogLayout.deviceIdOf(f.name) == deviceId) {
          await provider.deleteFile(f.id).timeout(const Duration(seconds: 8));
          _log.info('Retired changeset log file ${f.name}');
        }
      }
    } catch (e) {
      _log.warning('Could not retire changeset log for $deviceId: $e');
    }
  }

  /// Best-effort deletion of EVERY sync file in the cloud folder: all peers'
  /// per-device files, our own, the legacy shared file, and conflict copies.
  /// Failures are logged and skipped -- files that survive carry a stale (or
  /// missing) epoch stamp and are inert to every current-epoch device.
  Future<void> deleteAllSyncFiles(CloudStorageProvider provider) async {
    // Wipe both the changeset logs (ssv1.*) and any legacy full-file uploads.
    // The epoch/moved markers (submersion_library_*) match neither pattern, so
    // they survive -- a peer mid-replace still learns the new epoch.
    for (final pattern in [
      ChangesetLogLayout.prefix,
      CloudStorageProviderMixin.syncFileStem,
    ]) {
      try {
        final files = await provider
            .listFiles(namePattern: pattern)
            .timeout(const Duration(seconds: 8));
        for (final f in files) {
          try {
            await provider.deleteFile(f.id).timeout(const Duration(seconds: 8));
            _log.info('Deleted sync file ${f.name} for library replace');
          } catch (e) {
            _log.warning('Could not delete sync file ${f.name}: $e');
          }
        }
      } catch (e) {
        _log.warning('Could not list sync files for replace wipe: $e');
      }
    }
  }

  /// Delete EVERY sync artifact on [provider], INCLUDING the library epoch and
  /// moved markers that [deleteAllSyncFiles] intentionally preserves. A genuine
  /// fresh start (issue #509, cloud clear 3b): every device re-establishes from
  /// scratch. Best-effort; failures are logged and skipped.
  Future<void> wipeAllSyncData(CloudStorageProvider provider) async {
    await deleteAllSyncFiles(provider);
    for (final pattern in [libraryEpochFileName, libraryMovedFileName]) {
      try {
        final markers = await provider
            .listFiles(namePattern: pattern)
            .timeout(const Duration(seconds: 8));
        for (final f in markers) {
          try {
            await provider.deleteFile(f.id).timeout(const Duration(seconds: 8));
            _log.info('Deleted marker ${f.name} for full sync wipe');
          } catch (e) {
            _log.warning('Could not delete marker ${f.name}: $e');
          }
        }
      } catch (e) {
        _log.warning('Could not list markers for full sync wipe: $e');
      }
    }
  }

  /// Wipe all sync data on the active provider (issue #509, cloud clear 3b).
  /// No-op when no provider is configured.
  Future<void> wipeAllSyncDataOnActiveProvider() async {
    final provider = _cloudProvider;
    if (provider == null) return;
    await wipeAllSyncData(provider);
  }

  /// Execute the cloud side of a Replace restore: write the new epoch marker
  /// FIRST (a peer syncing mid-replace must learn the new epoch before it can
  /// misread a half-empty folder), wipe every sync file, upload our library
  /// stamped with the new epoch, then commit the epoch locally and clear the
  /// pending intent. On any failure the intent is kept so the next sync
  /// retries instead of merging.
  Future<SyncResult> executeLibraryReplace(LibraryEpochMarker marker) async {
    final provider = _cloudProvider;
    final store = _epochStore;
    if (provider == null || store == null) {
      return const SyncResult(
        status: SyncResultStatus.error,
        message: 'No cloud provider configured',
      );
    }
    try {
      if (!await provider.isAuthenticated()) {
        return const SyncResult(
          status: SyncResultStatus.authError,
          message: 'Not authenticated with cloud provider',
        );
      }
      final deviceId = await _syncRepository.getDeviceId();
      await _syncRepository.ensureSyncClockConfigured();

      await writeLibraryEpochMarker(provider, marker);
      await deleteAllSyncFiles(provider);

      final syncFolder = await provider.getOrCreateSyncFolder();
      // Cold-start the changeset log under the new epoch: the wipe removed our
      // cloud manifest, so the local publish position must be cleared too, or
      // the writer would append a changeset against a base that no longer
      // exists.
      final db = DatabaseService.instance.database;
      await PublishStateStore(db).resetForProvider(provider.providerId);
      await PeerCursorStore(db).resetForProvider(provider.providerId);

      final deletions = await _syncRepository.getAllDeletions();
      final uploadNonce = _uuid.v4();
      await _syncInitializer?.recordUploadNonce(
        uploadNonce,
        provider.providerId,
      );
      // Publish the new library as a fresh epoch-stamped base. Peers on the old
      // epoch halt for adoption; adopters rebuild from this base.
      await _changesetWriter.publish(
        provider: provider,
        deviceId: deviceId,
        folderId: syncFolder,
        deletions: deletions,
        epochId: marker.epochId,
        uploadNonce: uploadNonce,
      );

      final now = DateTime.now();
      await _syncRepository.setLastAcceptedEpochId(marker.epochId);
      await store.setLastAccepted(marker);
      await _syncRepository.updateLastSyncTime(
        now,
        providerId: provider.providerId,
      );
      await _syncRepository.persistSyncClock();
      await store.clearPendingReplace();
      _log.info('Library replace executed under epoch ${marker.epochId}');
      return SyncResult(
        status: SyncResultStatus.success,
        message: 'Library replaced',
        lastSyncTime: now,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Library replace failed; pending intent kept for retry',
        error: e,
        stackTrace: stackTrace,
      );
      return SyncResult(
        status: SyncResultStatus.error,
        message: 'Library replace failed: $e',
      );
    }
  }

  /// Adopt the replaced library: apply the current-epoch cloud files as
  /// authoritative -- upsert every record they contain and delete every
  /// local record (of synced entity types) they do not. Device identity is
  /// deliberately untouched: adoption changes data, not identity. The caller
  /// is responsible for the pre-adoption safety backup and any post-adoption
  /// fix-ups (active diver, follow-up sync).
  Future<SyncResult> adoptReplacedLibrary() async {
    final provider = _cloudProvider;
    final store = _epochStore;
    if (provider == null || store == null) {
      return const SyncResult(
        status: SyncResultStatus.error,
        message: 'No cloud provider configured',
      );
    }
    try {
      final marker = await readLibraryEpochMarker(provider);
      if (marker == null) {
        return const SyncResult(
          status: SyncResultStatus.error,
          message: 'No library replacement marker found',
        );
      }

      final folderId = await provider.getOrCreateSyncFolder();
      // Stream each epoch device's base to a temp file (bounded memory); the
      // streaming apply (#358) replaces the old in-memory collect + union,
      // which OOM-crashed iOS adopting a large library.
      final sources = await _collectEpochBaseSources(
        provider,
        folderId,
        marker.epochId,
      );
      if (sources.baseFilePaths.isEmpty) {
        // No current-format library for this epoch. If the marker is stale
        // (old-format backend or an orphaned replace), re-establish from the
        // local library rather than bricking; the notifier's follow-up sync
        // then publishes our base. Otherwise it is a replace in flight --
        // applying an empty set would wipe this library to zero, so wait.
        if (await _recoverUnreadableEpoch(provider, marker)) {
          return const SyncResult(
            status: SyncResultStatus.success,
            message:
                'The previous library could not be read; re-established this '
                'backend from this device\'s library.',
          );
        }
        return const SyncResult(
          status: SyncResultStatus.error,
          message:
              'The replaced library is still uploading. Try again shortly.',
        );
      }

      try {
        await _serializer.applyInDeferredFkTransaction(
          () => _adoptApplyStreaming(
            baseFilePaths: sources.baseFilePaths,
            baseExportedAt: sources.baseExportedAt,
            changesets: sources.changesets,
          ),
        );
      } finally {
        for (final path in sources.baseFilePaths) {
          await _baseSink.deleteQuietly(path);
        }
      }

      // Re-baseline under the adopted epoch. Our tombstones are obsolete --
      // the restored library is authoritative.
      await _syncRepository.resetSyncState(clearDeletionLog: true);
      // Record what adopt just applied as each epoch device's transport cursor.
      // resetSyncState wiped the cursors; without re-establishing them the next
      // sync cold-starts and redundantly re-downloads the whole base we just
      // adopted (the "slow second sync"). The streamed apply covered each
      // device through its `appliedThrough` seq, so the next pull skips it.
      final cursorStore = PeerCursorStore(DatabaseService.instance.database);
      for (final c in sources.cursors) {
        await cursorStore.upsert(
          peerDeviceId: c.deviceId,
          provider: provider.providerId,
          baseSeqApplied: c.baseSeq,
          lastSeqApplied: c.appliedThrough,
        );
      }
      // Record the deferred self-base marker: our library is now exactly the
      // adopted epoch, which the peers already published, so no sync may ever
      // re-upload it as our own full base (#358, the slow first sync after
      // adopt). Local changes publish as changesets against the adopted max
      // HLC recorded here; the log folds into a real base at compaction.
      await _publishStateStore.markAdoptedPendingBase(
        provider.providerId,
        await _syncRepository.maxRowHlc(),
      );
      await _syncRepository.setLastAcceptedEpochId(marker.epochId);
      await store.setLastAccepted(marker);
      SyncClock.instance.reset();
      _log.info('Adopted replaced library (epoch ${marker.epochId})');
      return const SyncResult(
        status: SyncResultStatus.success,
        message: 'Adopted the restored library',
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to adopt replaced library',
        error: e,
        stackTrace: stackTrace,
      );
      return SyncResult(
        status: SyncResultStatus.error,
        message: 'Failed to adopt the restored library: $e',
      );
    }
  }

  /// In-memory union/delete/upsert adopt apply (parity reference for the
  /// streaming path [_adoptApplyStreaming]). Runs inside the caller's
  /// deferred-FK transaction. Unions every payload's `data` (latest export
  /// wins; [payloads] must be sorted ascending by exportedAt), deletes local
  /// rows absent from the union, then upserts the union and repairs FKs.
  Future<void> _applyAdoptInMemory(
    List<SyncPayload> payloads,
    SyncPayload localSnapshot,
  ) async {
    // Union the restored records; for ids present in several files the latest
    // export wins (payloads are sorted ascending).
    final cloudIds = <String, Set<String>>{};
    final restored = <String, Map<String, Map<String, dynamic>>>{};
    for (final payload in payloads) {
      for (final entry in payload.data.toJson().entries) {
        final entityType = entry.key;
        final records = (entry.value as List).cast<Map<String, dynamic>>();
        for (final record in records) {
          final id = _recordIdForEntity(entityType, record);
          if (id == null) continue;
          (cloudIds[entityType] ??= <String>{}).add(id);
          (restored[entityType] ??= {})[id] = record;
        }
      }
    }

    // Delete local rows the restored library does not contain.
    for (final entry in localSnapshot.data.toJson().entries) {
      final entityType = entry.key;
      final records = (entry.value as List).cast<Map<String, dynamic>>();
      for (final record in records) {
        final id = _recordIdForEntity(entityType, record);
        if (id == null) continue;
        if (!(cloudIds[entityType]?.contains(id) ?? false)) {
          await _serializer.deleteRecord(entityType, id);
        }
      }
    }

    // Upsert every restored record.
    for (final entry in restored.entries) {
      for (final record in entry.value.values) {
        await _serializer.upsertRecord(entry.key, record);
      }
    }

    await _serializer.repairDanglingForeignKeys();
  }

  /// Test seam: in-memory adopt of [payloads] (the parity reference). Captures
  /// the local snapshot, sorts payloads ascending, and applies in one
  /// deferred-FK transaction. No re-baseline, so a parity comparison sees only
  /// the data effects. See sync_adopt_streaming_parity_test.dart.
  @visibleForTesting
  Future<void> debugAdoptInMemory(List<SyncPayload> payloads) async {
    final local = await _serializer.exportData(
      deviceId: 'adopt',
      deletions: const [],
    );
    final sorted = [...payloads]
      ..sort((a, b) => a.exportedAt.compareTo(b.exportedAt));
    await _serializer.applyInDeferredFkTransaction(
      () => _applyAdoptInMemory(sorted, local),
    );
  }

  /// Streaming replace-adopt apply (production path). Runs inside the caller's
  /// deferred-FK transaction. Clears every synced table, then upserts every
  /// restored row in exportedAt order (each base temp file streamed in 500-row
  /// batches, plus in-memory changesets), then repairs FKs. Bounded memory: one
  /// batch of rows at a time, independent of library size -- unlike the old
  /// path it holds NO id set (#358 adopt OOM: a full-library cloud-id set plus
  /// per-entity local-id sets pushed a large library past the iOS jetsam
  /// limit).
  ///
  /// Equivalent to [_applyAdoptInMemory]: clearing then re-inserting the cloud
  /// union yields the same final rows as upsert-then-delete-not-in-cloud (both
  /// converge the DB to the cloud union), `upsertRecord` is an unconditional
  /// overwrite so ascending exportedAt order is latest-export-wins, and a null
  /// record id is skipped exactly as the in-memory path does. Enforced by
  /// sync_adopt_streaming_parity_test.dart.
  Future<void> _adoptApplyStreaming({
    required List<String> baseFilePaths,
    required List<int> baseExportedAt,
    required List<SyncPayload> changesets,
  }) async {
    // Replace semantics: clear every synced table, then insert the cloud union
    // (latest export wins). Equivalent to the old upsert-then-delete-not-in-
    // cloud, but needs no in-RAM id set to diff against, so adopt memory stays
    // bounded regardless of library size (#358 adopt OOM).
    for (final entity in entityHasUpdatedAt.keys) {
      await _serializer.deleteAllRecords(entity);
    }

    // Batched upsert of a table's rows (skipping null-id rows, matching the
    // in-memory path). Batching is the throughput lever: a large adopt is
    // millions of rows, and row-by-row upserts froze the UI (#358 adopt).
    Future<void> applyBatch(
      String table,
      List<Map<String, dynamic>> records,
    ) async {
      final valid = [
        for (final r in records)
          if (_recordIdForEntity(table, r) != null) r,
      ];
      if (valid.isEmpty) return;
      await _serializer.upsertRecords(table, valid);
    }

    // Apply units: each base file and each changeset, ascending by exportedAt
    // (latest export wins under the unconditional upsert).
    final units = <({int at, String? file, SyncPayload? changeset})>[
      for (var i = 0; i < baseFilePaths.length; i++)
        (at: baseExportedAt[i], file: baseFilePaths[i], changeset: null),
      for (final c in changesets) (at: c.exportedAt, file: null, changeset: c),
    ]..sort((a, b) => a.at.compareTo(b.at));

    for (final unit in units) {
      final changeset = unit.changeset;
      if (changeset != null) {
        for (final entry in changeset.data.toJson().entries) {
          if (!entityHasUpdatedAt.containsKey(entry.key)) continue;
          await applyBatch(
            entry.key,
            (entry.value as List).cast<Map<String, dynamic>>(),
          );
        }
        continue;
      }

      // Base file: stream `data` rows, batching 500 per table.
      const batchSize = 500;
      String? currentTable;
      var batch = <Map<String, dynamic>>[];
      Future<void> flush() async {
        final table = currentTable;
        if (table == null || batch.isEmpty) return;
        await applyBatch(table, batch);
        batch = <Map<String, dynamic>>[];
      }

      await BaseJsonStreamReader().parse(
        File(unit.file!).openRead(),
        wantRows: (section, table) =>
            section == 'data' && entityHasUpdatedAt.containsKey(table),
        onRow: (section, table, rowBytes) async {
          if (table != currentTable) {
            await flush();
            currentTable = table;
          }
          batch.add(jsonDecode(utf8.decode(rowBytes)) as Map<String, dynamic>);
          if (batch.length >= batchSize) await flush();
        },
      );
      await flush();
    }

    await _serializer.repairDanglingForeignKeys();
  }

  /// Test seam: streaming adopt of base temp files + in-memory changesets.
  @visibleForTesting
  Future<void> debugAdoptStreaming(
    List<String> baseFilePaths,
    List<int> baseExportedAt,
    List<SyncPayload> changesets,
  ) => _serializer.applyInDeferredFkTransaction(
    () => _adoptApplyStreaming(
      baseFilePaths: baseFilePaths,
      baseExportedAt: baseExportedAt,
      changesets: changesets,
    ),
  );

  /// True when we adopted a restored library and have nothing of our own to
  /// publish yet -- so this sync skips the publish entirely (saving a nonce
  /// ring slot and the manifest round-trip). This gate is an optimization
  /// only: if it misfires towards publishing, the writer sees no rows above
  /// the adopted watermark and no-ops.
  ///
  /// The marker is a publish-state row with a null `baseSeq`: adopt records
  /// it, and it stays null while the writer publishes post-adopt changesets
  /// without a base, until compaction folds the log into a real base (or a
  /// cloud-manifest-lost cold-start re-bases). A device that has published a
  /// base (baseSeq set) or never adopted (no row at all) falls straight
  /// through and publishes normally. The skip clears the moment we have any
  /// local change: [SyncRepository.hasUnsyncedChanges] counts pending / conflict
  /// / deletion rows, which are written in the same transaction as the edit, so
  /// it is reliable even in the window before the HLC clock is reconfigured.
  Future<bool> _shouldSkipPublishAfterAdopt(
    String providerId,
    List<DeletionLogData> deletions,
  ) async {
    final state = await _publishStateStore.get(providerId);
    if (state == null || state.baseSeq != null) return false;
    // Equivalent to !hasUnsyncedChanges(), but reuses the [deletions] the caller
    // already fetched instead of re-reading the deletion log on this path.
    if (deletions.isNotEmpty) return false;
    return (await _syncRepository.getPendingCount()) == 0 &&
        (await _syncRepository.getConflictCount()) == 0;
  }

  /// Stream every epoch-stamped changeset log into adopt sources: each device's
  /// base assembled to a temp file (bounded memory, via [BasePartFileSink],
  /// which verifies per-part and whole-file checksums as bytes land), its base
  /// export time, and its post-base changesets decoded in memory (small
  /// deltas). Skips a device whose base parts are not all present or whose base
  /// fails its checksum (a publish still in flight -> retry next adopt).
  /// Replaces the old in-memory collect that decoded every device's whole base
  /// into RAM and OOM-crashed iOS adopting a large library (#358). The caller
  /// owns the returned temp files and must delete them.
  Future<
    ({
      List<String> baseFilePaths,
      List<int> baseExportedAt,
      List<SyncPayload> changesets,
      List<({String deviceId, int baseSeq, int appliedThrough})> cursors,
    })
  >
  _collectEpochBaseSources(
    CloudStorageProvider provider,
    String folderId,
    String epochId,
  ) async {
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: ChangesetLogLayout.prefix,
    );
    final byName = {for (final f in files) f.name: f};
    final deviceIds = <String>{
      for (final f in files)
        if (ChangesetLogLayout.deviceIdOf(f.name) != null)
          ChangesetLogLayout.deviceIdOf(f.name)!,
    };
    final baseFilePaths = <String>[];
    final baseExportedAt = <int>[];
    final changesets = <SyncPayload>[];
    final cursors = <({String deviceId, int baseSeq, int appliedThrough})>[];
    for (final deviceId in deviceIds) {
      final manifestFile = byName[ChangesetLogLayout.manifestName(deviceId)];
      if (manifestFile == null) continue;
      SyncManifest manifest;
      try {
        manifest = SyncManifest.fromBytes(
          await provider.downloadFile(manifestFile.id),
        );
      } catch (_) {
        continue;
      }
      if (manifest.epochId != epochId) continue;
      final baseSeq = manifest.baseSeq;
      if (baseSeq == null) continue;
      final partCount = manifest.basePartCount ?? 0;
      if (partCount <= 0) continue;
      final path = await _baseSink.assemble(
        name: 'ssv1_adopt_${deviceId}_$baseSeq',
        partCount: partCount,
        wholeChecksum: manifest.baseChecksum,
        partChecksums: manifest.basePartChecksums,
        downloadPart: (i) async {
          final pf =
              byName[ChangesetLogLayout.basePartName(deviceId, baseSeq, i)];
          if (pf == null) return null;
          return provider.downloadFile(pf.id);
        },
      );
      if (path == null) continue; // base incomplete/corrupt -> skip this device
      baseFilePaths.add(path);
      baseExportedAt.add(await _readBaseExportedAt(path));
      // Track the last CONTIGUOUS seq we apply (base, then changesets up to the
      // first gap) so adopt can record it as this peer's cursor -- otherwise the
      // next sync cold-starts and re-downloads the whole base we just applied.
      var appliedThrough = baseSeq;
      for (var seq = baseSeq + 1; seq <= manifest.headSeq; seq++) {
        final cf = byName[ChangesetLogLayout.changesetName(deviceId, seq)];
        if (cf == null) break;
        changesets.add(
          _changesetCodec.decodeChangeset(await provider.downloadFile(cf.id)),
        );
        appliedThrough = seq;
      }
      cursors.add((
        deviceId: deviceId,
        baseSeq: baseSeq,
        appliedThrough: appliedThrough,
      ));
    }
    return (
      baseFilePaths: baseFilePaths,
      baseExportedAt: baseExportedAt,
      changesets: changesets,
      cursors: cursors,
    );
  }

  /// Read a base file's `exportedAt` (the cross-device latest-wins order key)
  /// from a bounded prefix rather than parsing the whole base: it is the second
  /// top-level member of the payload JSON, always within the first bytes. 0 if
  /// absent (an unstamped/legacy base sorts first, which is the safe default).
  Future<int> _readBaseExportedAt(String path) async {
    final bytes = <int>[];
    await for (final chunk in File(path).openRead(0, 65536)) {
      bytes.addAll(chunk);
    }
    final head = utf8.decode(bytes, allowMalformed: true);
    final match = RegExp(r'"exportedAt"\s*:\s*(\d+)').firstMatch(head);
    return match == null ? 0 : (int.tryParse(match.group(1)!) ?? 0);
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

  /// Download and parse the cloud "library moved" marker, or null when absent.
  /// Unlike the epoch marker this returns null on any failure rather than
  /// throwing: the moved marker is purely advisory, so an unreadable one must
  /// never fail a sync closed.
  Future<LibraryMovedMarker?> readLibraryMovedMarker(
    CloudStorageProvider provider,
  ) async {
    try {
      final files = await provider
          .listFiles(namePattern: libraryMovedFileName)
          .timeout(const Duration(seconds: 8));
      final candidates = files
          .where((f) => !_isConflictCopy(f.name))
          .where((f) => f.name == libraryMovedFileName)
          .toList();
      if (candidates.isEmpty) return null;
      candidates.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
      final bytes = await provider
          .downloadFile(candidates.first.id)
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      return LibraryMovedMarker.fromJson(decoded);
    } catch (e) {
      _log.warning('Could not read library moved marker: $e');
      return null;
    }
  }

  /// Write the "library moved" marker to [provider] (the OLD backend). Left
  /// behind on switch so a straggler still pointed at this backend learns the
  /// library moved on. Best-effort: never throws.
  Future<void> writeLibraryMovedMarker(
    CloudStorageProvider provider,
    LibraryMovedMarker marker,
  ) async {
    try {
      final bytes = Uint8List.fromList(
        utf8.encode(jsonEncode(marker.toJson())),
      );
      String? folderId;
      try {
        folderId = await provider.getOrCreateSyncFolder();
      } catch (_) {
        folderId = null;
      }
      await provider
          .uploadFile(bytes, libraryMovedFileName, folderId: folderId)
          .timeout(const Duration(seconds: 60));
      _log.info('Wrote library moved marker -> ${marker.toProviderId}');
    } catch (e) {
      _log.warning('Could not write library moved marker: $e');
    }
  }

  /// Remove the orphaned sync payload files from a backend the user switched
  /// away from. Deletes the dive-library data files (the privacy/cost concern)
  /// but deliberately KEEPS the moved marker: it carries no dive data and
  /// still tells any not-yet-migrated straggler where the library went.
  /// Best-effort; never throws.
  Future<void> cleanupOldBackend(CloudStorageProvider provider) async {
    await deleteAllSyncFiles(provider);
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
