import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';

/// Handles sync initialization and checks on app launch
class SyncInitializer {
  static final _log = LoggerService.forClass(SyncInitializer);

  final _uuid = const Uuid();

  static const _lastProviderKey = 'sync_last_provider';

  /// Mirrors the in-DB sync device id outside the database (which a restore
  /// would otherwise rewind silently). A mismatch on launch is one signal that
  /// the database was replaced by a restore. See [reconcileDeviceIdentity].
  static const _deviceIdSentinelKey = 'sync_device_id_sentinel';

  /// Mirrors the database instance token outside the database. The token is
  /// rotated each launch, so a restored backup carries a stale token that no
  /// longer matches this copy -- the primary restore signal, and the one that
  /// catches a same-device backup (whose device id is unchanged). See
  /// [reconcileDeviceIdentity].
  static const _dbInstanceTokenKey = 'sync_db_instance_token';

  /// Recent nonces this install has stamped into its uploads, keyed per
  /// provider (each provider holds its own copy of our per-device file, so
  /// each needs its own ring -- a single flat ring would let heavy syncing
  /// on one provider evict the nonce last written to another). A small ring
  /// (not just the latest) so an eventually-consistent provider showing a
  /// slightly stale copy of our own file does not read as foreign.
  static const _uploadNoncesKeyPrefix = 'sync_upload_nonces_';
  static const _maxRecordedNonces = 8;

  String _uploadNoncesKey(String providerId) =>
      '$_uploadNoncesKeyPrefix$providerId';

  final SyncRepository _syncRepository;
  final SharedPreferences _prefs;

  SyncInitializer({
    required SyncRepository syncRepository,
    required SharedPreferences prefs,
  }) : _syncRepository = syncRepository,
       _prefs = prefs;

  /// Get the last used cloud provider type
  CloudProviderType? getLastProvider() {
    final providerString = _prefs.getString(_lastProviderKey);
    if (providerString == null) return null;

    try {
      return CloudProviderType.values.firstWhere(
        (p) => p.name == providerString,
      );
    } catch (e) {
      return null;
    }
  }

  /// Save the selected cloud provider
  Future<void> saveProvider(CloudProviderType? provider) async {
    if (provider == null) {
      await _prefs.remove(_lastProviderKey);
    } else {
      await _prefs.setString(_lastProviderKey, provider.name);
    }
  }

  /// Reconcile this installation's sync identity against the anchors mirrored
  /// outside the database, detecting (and recovering from) a database restore.
  ///
  /// All sync bookkeeping (device id, HLC clock, last-sync timestamp, cursors,
  /// deletion log) lives inside the database, so a whole-DB restore rewinds it
  /// to the backup's snapshot -- which stalls sync and lets a peer's still-live
  /// copy keep resurrecting deletes. Two values mirrored in SharedPreferences
  /// survive the restore and reveal it:
  ///
  /// - the **instance token** (rotated each launch) -- the primary signal. A
  ///   restored backup carries a stale token that no longer matches the mirror,
  ///   so this catches even a same-device backup whose device id is unchanged.
  /// - the **device id** -- a secondary signal; a restored foreign backup also
  ///   changes the in-DB device id. It additionally names the identity to
  ///   preserve through the re-baseline.
  ///
  /// Outcomes:
  /// - No anchors yet: establish them ([DeviceIdentityStatus.seeded]). A restore
  ///   predating the anchors cannot be detected and needs a one-time manual
  ///   Reset Sync State to recover.
  /// - On-disk DB is the one we last wrote: rotate the token and continue
  ///   ([DeviceIdentityStatus.unchanged]).
  /// - On-disk DB is not the one we last wrote: a restore swapped it.
  ///   Re-baseline sync, preserving the live device identity
  ///   ([DeviceIdentityStatus.rebaselined]).
  ///
  /// Never throws: a reconcile failure must not block app launch.
  Future<DeviceIdentityStatus> reconcileDeviceIdentity() async {
    try {
      final deviceId = await _syncRepository.getDeviceId();
      final dbToken = await _syncRepository.getInstanceToken();
      final mirroredToken = _prefs.getString(_dbInstanceTokenKey);
      final sentinelDeviceId = _prefs.getString(_deviceIdSentinelKey);

      // First run (or first launch after this detection shipped): nothing to
      // compare against. Establish the anchors. A restore that predates them
      // cannot be detected and needs a manual Reset Sync State.
      if (mirroredToken == null || sentinelDeviceId == null) {
        await _establishAnchors(deviceId);
        _log.info('Seeded sync restore-detection anchors');
        return DeviceIdentityStatus.seeded;
      }

      // The on-disk DB must be the one we last wrote. The instance token is the
      // primary signal (it catches a same-device backup, whose device id is
      // unchanged); a device-id change is a secondary signal kept as a belt.
      final restoreDetected =
          dbToken == null ||
          dbToken != mirroredToken ||
          sentinelDeviceId != deviceId;

      if (restoreDetected) {
        _log.warning(
          'On-disk database is not the one we last wrote (restore/overwrite '
          'detected); re-baselining sync and restoring the live identity',
        );
        await _syncRepository.rebaselineAfterRestore(
          preserveDeviceId: sentinelDeviceId,
          preserveEpochId: LibraryEpochStore(_prefs).lastAcceptedEpochId,
        );
        // Re-establish anchors on the restored DB, mirroring the preserved id.
        await _establishAnchors(sentinelDeviceId);
        return DeviceIdentityStatus.rebaselined;
      }

      // Normal launch: rotate the token so a backup taken of this state becomes
      // distinguishable from the live DB on a future restore.
      await _establishAnchors(deviceId);
      return DeviceIdentityStatus.unchanged;
    } catch (e, stackTrace) {
      _log.error(
        'Device-identity reconcile failed; continuing launch',
        error: e,
        stackTrace: stackTrace,
      );
      return DeviceIdentityStatus.error;
    }
  }

  /// Rotate the database instance token and mirror it -- plus [deviceId] --
  /// into SharedPreferences, so the next launch can tell whether the on-disk DB
  /// is still the one we last wrote.
  Future<void> _establishAnchors(String deviceId) async {
    final token = await _syncRepository.rotateInstanceToken();
    await _prefs.setString(_dbInstanceTokenKey, token);
    await _prefs.setString(_deviceIdSentinelKey, deviceId);
  }

  /// Mint a brand-new sync identity for this installation: a fresh device id
  /// persisted to the database and mirrored into the launch anchors, with a
  /// freshly rotated instance token.
  ///
  /// This is the recovery path for a cloned identity -- two installs syncing
  /// as the same device after cross-device backup/restore choreography. Each
  /// twin lists the shared per-device sync file as "its own", sees no peers,
  /// and silently overwrites the other's uploads. [reconcileDeviceIdentity]
  /// deliberately preserves the anchored identity (correct for same-device
  /// restores), so a clone survives every restore and reset; only minting a
  /// new id -- and anchoring it so the next launch does not revert it -- can
  /// split the twins. Returns the new device id.
  Future<String> adoptFreshIdentity() async {
    final newId = _uuid.v4();
    await _syncRepository.setDeviceId(newId);
    await _establishAnchors(newId);
    // Drop the in-memory clock so HLC stamps re-seed under the new node id.
    SyncClock.instance.reset();
    _log.info('Adopted a fresh sync identity');
    return newId;
  }

  List<String> _recordedUploadNonces(String providerId) =>
      _prefs.getStringList(_uploadNoncesKey(providerId)) ?? const [];

  /// Record a nonce this install is stamping into an upload to [providerId].
  Future<void> recordUploadNonce(String nonce, String providerId) async {
    final nonces = [nonce, ..._recordedUploadNonces(providerId)];
    await _prefs.setStringList(
      _uploadNoncesKey(providerId),
      nonces.take(_maxRecordedNonces).toList(),
    );
  }

  /// Best-effort removal of a speculatively recorded nonce after its upload
  /// failed outright. Never throws.
  Future<void> removeUploadNonce(String nonce, String providerId) async {
    try {
      final nonces = _recordedUploadNonces(
        providerId,
      ).where((n) => n != nonce).toList();
      await _prefs.setStringList(_uploadNoncesKey(providerId), nonces);
    } catch (_) {
      // Losing this cleanup only costs a ring slot.
    }
  }

  /// Whether [nonce], read back from this install's OWN per-device cloud
  /// file on [providerId], was minted by someone else. True means another
  /// install is uploading under this device id (a twin). A null nonce is
  /// never foreign: it was written by a pre-nonce build of this same device,
  /// and flagging it would false-positive every upgrader's first sync.
  bool isForeignUploadNonce(String? nonce, String providerId) {
    if (nonce == null) return false;
    return !_recordedUploadNonces(providerId).contains(nonce);
  }

  /// Check sync status on app launch
  ///
  /// Returns a [SyncCheckResult] indicating if there are updates available
  /// or if sync should be triggered.
  Future<SyncCheckResult> checkSyncOnLaunch(
    CloudStorageProvider? provider,
  ) async {
    if (provider == null) {
      return const SyncCheckResult(
        status: SyncCheckStatus.notConfigured,
        message: 'No cloud provider configured',
      );
    }

    try {
      // Check if available
      if (!await provider.isAvailable()) {
        return SyncCheckResult(
          status: SyncCheckStatus.unavailable,
          message: '${provider.providerName} is not available on this device',
        );
      }

      // Check if authenticated
      if (!await provider.isAuthenticated()) {
        return SyncCheckResult(
          status: SyncCheckStatus.notAuthenticated,
          message: 'Not signed in to ${provider.providerName}',
        );
      }

      // Get local last sync time, scoped to this provider: a cursor from a
      // backend we switched away from must not read as "synced here", or the
      // launch check would report up-to-date against a backend we have never
      // actually synced with.
      final localLastSync = await _syncRepository.getLastSyncTime(
        forProvider: provider.providerId,
      );

      // Per-device sync files: every device writes its own
      // submersion_sync_<deviceId>.json. Whether a launch sync is worthwhile is
      // decided from the newest *peer* file (all sync files except our own and
      // any iCloud "conflicted copy" duplicates), not a single canonical remote
      // file -- our own file's mtime tracks our own uploads and would never
      // reveal another device's changes.
      final peerFiles = await peerSyncFiles(provider);

      if (peerFiles.isEmpty) {
        // No other device has uploaded yet. Still surface unsynced local edits
        // so the first push is recommended.
        final pendingCount = await _syncRepository.getPendingCount();
        if (pendingCount > 0) {
          return SyncCheckResult(
            status: SyncCheckStatus.localChanges,
            message:
                '$pendingCount local change${pendingCount == 1 ? '' : 's'} to upload',
            localLastSync: localLastSync,
            pendingChanges: pendingCount,
          );
        }
        return const SyncCheckResult(
          status: SyncCheckStatus.noRemoteData,
          message: 'No sync data found in cloud',
        );
      }

      final remoteModified = _newestModified(peerFiles);

      // Compare timestamps
      if (localLastSync == null) {
        return SyncCheckResult(
          status: SyncCheckStatus.updatesAvailable,
          message: 'Cloud data available',
          remoteModified: remoteModified,
        );
      }

      if (remoteModified.isAfter(localLastSync)) {
        return SyncCheckResult(
          status: SyncCheckStatus.updatesAvailable,
          message: 'Updates available from cloud',
          localLastSync: localLastSync,
          remoteModified: remoteModified,
        );
      }

      // Check for pending local changes
      final pendingCount = await _syncRepository.getPendingCount();
      if (pendingCount > 0) {
        return SyncCheckResult(
          status: SyncCheckStatus.localChanges,
          message:
              '$pendingCount local change${pendingCount == 1 ? '' : 's'} to upload',
          localLastSync: localLastSync,
          pendingChanges: pendingCount,
        );
      }

      return SyncCheckResult(
        status: SyncCheckStatus.upToDate,
        message: 'Everything is up to date',
        localLastSync: localLastSync,
      );
    } catch (e, stackTrace) {
      _log.error('Sync check failed', error: e, stackTrace: stackTrace);
      return SyncCheckResult(
        status: SyncCheckStatus.error,
        message: 'Sync check failed: $e',
      );
    }
  }

  /// Lists every *other* device's changeset-log manifest -- one per peer
  /// device, our own excluded. A manifest's modifiedTime tracks that peer's
  /// last publish, which is the freshness signal both the launch check and the
  /// first-contact guard need. iCloud "conflicted copy" duplicates are
  /// naturally excluded: they do not end in the canonical `.manifest.json`.
  Future<List<CloudFileInfo>> peerSyncFiles(
    CloudStorageProvider provider,
  ) async {
    final deviceId = await _syncRepository.getDeviceId();
    final files = await provider.listFiles(
      namePattern: ChangesetLogLayout.prefix,
    );
    return files
        .where((f) => ChangesetLogLayout.isManifest(f.name))
        .where((f) => ChangesetLogLayout.deviceIdOf(f.name) != deviceId)
        .toList();
  }

  /// The most recent modifiedTime across [files], which must be non-empty.
  DateTime _newestModified(List<CloudFileInfo> files) {
    var newest = files.first.modifiedTime;
    for (final f in files.skip(1)) {
      if (f.modifiedTime.isAfter(newest)) newest = f.modifiedTime;
    }
    return newest;
  }
}

/// Outcome of [SyncInitializer.reconcileDeviceIdentity].
enum DeviceIdentityStatus {
  /// No anchors existed yet; the instance token and device id were recorded.
  /// First run, or first launch after this detection shipped. A restore
  /// predating the anchors cannot be detected and needs a manual Reset Sync
  /// State.
  seeded,

  /// The anchors still matched the on-disk database. Normal launch; the
  /// instance token was rotated for next time.
  unchanged,

  /// The on-disk database no longer matched the mirrored anchors -- a changed
  /// instance token (the primary signal, which catches a same-device backup),
  /// or a changed device id: a restore replaced the database. Sync was
  /// re-baselined and the live identity restored.
  rebaselined,

  /// The reconcile could not run (e.g. the metadata lookup failed). Launch
  /// continues regardless.
  error,
}

/// Status of the sync check
enum SyncCheckStatus {
  /// No cloud provider configured
  notConfigured,

  /// Provider not available on this platform
  unavailable,

  /// User not authenticated with provider
  notAuthenticated,

  /// No remote sync data found (first sync needed)
  noRemoteData,

  /// Remote sync file was deleted
  remoteFileDeleted,

  /// Remote has newer data - sync recommended
  updatesAvailable,

  /// Local has unsynced changes
  localChanges,

  /// Everything is in sync
  upToDate,

  /// Error checking sync status
  error,
}

/// Result of a sync check operation
class SyncCheckResult {
  final SyncCheckStatus status;
  final String message;
  final DateTime? localLastSync;
  final DateTime? remoteModified;
  final int pendingChanges;

  const SyncCheckResult({
    required this.status,
    required this.message,
    this.localLastSync,
    this.remoteModified,
    this.pendingChanges = 0,
  });

  /// Whether sync should be recommended to the user
  bool get shouldRecommendSync =>
      status == SyncCheckStatus.updatesAvailable ||
      status == SyncCheckStatus.localChanges ||
      status == SyncCheckStatus.noRemoteData;

  /// Whether there's an issue that needs user attention
  bool get needsUserAttention =>
      status == SyncCheckStatus.notAuthenticated ||
      status == SyncCheckStatus.remoteFileDeleted ||
      status == SyncCheckStatus.error;

  @override
  String toString() => 'SyncCheckResult($status: $message)';
}
