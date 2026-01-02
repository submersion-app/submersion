import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/sync_repository.dart';
import '../cloud_storage/cloud_storage_provider.dart';
import '../logger_service.dart';

/// Handles sync initialization and checks on app launch
class SyncInitializer {
  static final _log = LoggerService.forClass(SyncInitializer);

  static const _lastProviderKey = 'sync_last_provider';

  final SyncRepository _syncRepository;
  final SharedPreferences _prefs;

  SyncInitializer({
    required SyncRepository syncRepository,
    required SharedPreferences prefs,
  })  : _syncRepository = syncRepository,
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

      // Get local last sync time
      final localLastSync = await _syncRepository.getLastSyncTime();
      final remoteFileId = await _syncRepository.getRemoteFileId();

      if (remoteFileId == null) {
        // No remote file yet - first sync needed
        return const SyncCheckResult(
          status: SyncCheckStatus.noRemoteData,
          message: 'No sync data found in cloud',
        );
      }

      // Check remote file info
      final remoteInfo = await provider.getFileInfo(remoteFileId);

      if (remoteInfo == null) {
        return const SyncCheckResult(
          status: SyncCheckStatus.remoteFileDeleted,
          message: 'Remote sync file was deleted',
        );
      }

      // Compare timestamps
      if (localLastSync == null) {
        return SyncCheckResult(
          status: SyncCheckStatus.updatesAvailable,
          message: 'Cloud data available',
          remoteModified: remoteInfo.modifiedTime,
        );
      }

      if (remoteInfo.modifiedTime.isAfter(localLastSync)) {
        return SyncCheckResult(
          status: SyncCheckStatus.updatesAvailable,
          message: 'Updates available from cloud',
          localLastSync: localLastSync,
          remoteModified: remoteInfo.modifiedTime,
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
      _log.error('Sync check failed', e, stackTrace);
      return SyncCheckResult(
        status: SyncCheckStatus.error,
        message: 'Sync check failed: $e',
      );
    }
  }
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
