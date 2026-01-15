import 'dart:async';
import 'dart:typed_data';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

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
      status == SyncResultStatus.noChanges;

  @override
  String toString() =>
      'SyncResult(status: $status, records: $recordsSynced, conflicts: $conflictsFound)';
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
          // Parse the conflict data to create a SyncConflict object
          // The conflict data contains the remote version
          final remoteData = _parseConflictData(record.conflictData!);
          conflicts.add(
            SyncConflict(
              entityType: record.entityType,
              recordId: record.recordId,
              localData: {}, // Would need to fetch from database
              remoteData: remoteData,
              localModified: DateTime.fromMillisecondsSinceEpoch(
                record.localUpdatedAt,
              ),
              remoteModified: DateTime.now(), // Would come from remote data
            ),
          );
        } catch (e) {
          _log.error(
            'Failed to parse conflict data for ${record.recordId}',
            e,
            null,
          );
        }
      }
    }

    return conflicts;
  }

  Map<String, dynamic> _parseConflictData(String json) {
    // Simple JSON parsing - in a real implementation would use proper deserialization
    return {};
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
      _log.error('No cloud provider configured', null, null);
      return const SyncResult(
        status: SyncResultStatus.error,
        message: 'No cloud provider configured',
      );
    }

    _log.debug('Using provider: ${provider.providerName}');

    try {
      _reportProgress(SyncPhase.preparing, 0.0, 'Preparing sync...');

      // Check authentication
      final isAuth = await provider.isAuthenticated();
      _log.debug('isAuthenticated = $isAuth');
      if (!isAuth) {
        return const SyncResult(
          status: SyncResultStatus.authError,
          message: 'Not authenticated with cloud provider',
        );
      }

      // Get device ID and last sync time
      final deviceId = await _syncRepository.getDeviceId();
      final lastSyncTime = await _syncRepository.getLastSyncTime();
      final deletions = await _syncRepository.getAllDeletions();

      _reportProgress(SyncPhase.exporting, 0.1, 'Exporting local data...');

      // Export local data (full export for now, incremental later)
      final localPayload = await _serializer.exportData(
        deviceId: deviceId,
        since: null, // Full export - can optimize later for incremental
        lastSyncTimestamp: lastSyncTime?.millisecondsSinceEpoch,
        deletions: deletions,
      );

      _reportProgress(SyncPhase.exporting, 0.3, 'Serializing data...');

      final localJson = _serializer.serializePayload(localPayload);
      final localData = Uint8List.fromList(localJson.codeUnits);

      // Try to download existing remote file
      _reportProgress(
        SyncPhase.downloading,
        0.4,
        'Checking for remote data...',
      );

      SyncPayload? remotePayload;
      final remoteFileId = await _syncRepository.getRemoteFileId();

      if (remoteFileId != null) {
        try {
          final remoteData = await provider.downloadFile(remoteFileId);
          final remoteJson = String.fromCharCodes(remoteData);
          remotePayload = _serializer.deserializePayload(remoteJson);

          // Validate checksum
          if (!_serializer.validateChecksum(remotePayload)) {
            _log.warning('Remote sync file has invalid checksum');
            remotePayload = null;
          }
        } catch (e) {
          _log.warning('Failed to download remote sync file: $e');
          // Continue with upload-only sync
        }
      }

      _reportProgress(SyncPhase.importing, 0.6, 'Processing changes...');

      // For now, we do a simple strategy:
      // - If no remote file, just upload local
      // - If remote file exists and is from same device, update it
      // - If from different device, would need conflict resolution

      const recordsSynced = 0;
      const conflictsFound = 0;

      if (remotePayload != null && remotePayload.deviceId != deviceId) {
        // Different device - check for conflicts
        // This is a simplified implementation - full merge logic would be more complex
        _log.info(
          'Remote data from different device: ${remotePayload.deviceId}',
        );
        // For now, we skip conflict detection and just upload
        // A full implementation would compare records and detect conflicts
      }

      _reportProgress(SyncPhase.uploading, 0.8, 'Uploading sync data...');

      // Upload to cloud
      _log.debug('Getting sync folder...');
      final syncFolder = await provider.getOrCreateSyncFolder();
      _log.debug('Sync folder = $syncFolder');
      const filename = 'submersion_sync.json';

      _log.debug(
        'Uploading ${localData.length} bytes to $syncFolder/$filename...',
      );
      final result = await provider.uploadFile(
        localData,
        filename,
        folderId: syncFolder,
      );
      _log.debug('Upload complete! fileId = ${result.fileId}');

      // Update sync state
      await _syncRepository.setRemoteFileId(result.fileId);
      await _syncRepository.updateLastSyncTime(result.uploadTime);

      // Clear deletion log after successful sync
      await _syncRepository.clearAllDeletions();

      _reportProgress(SyncPhase.complete, 1.0, 'Sync complete');

      _log.info('Sync completed successfully');

      return SyncResult(
        status: conflictsFound > 0
            ? SyncResultStatus.hasConflicts
            : SyncResultStatus.success,
        recordsSynced: recordsSynced,
        conflictsFound: conflictsFound,
        lastSyncTime: result.uploadTime,
      );
    } on CloudStorageException catch (e) {
      _log.error('Cloud storage error during sync', e, e.stackTrace);
      return SyncResult(
        status: SyncResultStatus.networkError,
        message: e.message,
      );
    } catch (e, stackTrace) {
      _log.error('Sync failed', e, stackTrace);
      return SyncResult(status: SyncResultStatus.error, message: e.toString());
    }
  }

  /// Resolve a conflict with the user's chosen resolution
  Future<void> resolveConflict(
    String entityType,
    String recordId,
    ConflictResolution resolution,
  ) async {
    _log.info('Resolving conflict for $entityType/$recordId with $resolution');

    switch (resolution) {
      case ConflictResolution.keepLocal:
        // Just clear the conflict, local data is already current
        await _syncRepository.clearConflict(
          entityType: entityType,
          recordId: recordId,
        );
        break;

      case ConflictResolution.keepRemote:
        // Would need to apply the remote data to the database
        // Then clear the conflict
        await _syncRepository.clearConflict(
          entityType: entityType,
          recordId: recordId,
        );
        break;

      case ConflictResolution.keepBoth:
        // Would need to create a duplicate record with the remote data
        // Then clear the conflict
        await _syncRepository.clearConflict(
          entityType: entityType,
          recordId: recordId,
        );
        break;
    }
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
