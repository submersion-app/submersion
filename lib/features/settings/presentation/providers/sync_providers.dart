import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/repositories/sync_repository.dart';
import '../../../../core/domain/entities/storage_config.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/cloud_storage/cloud_storage_provider.dart';
import '../../../../core/services/cloud_storage/google_drive_storage_provider.dart';
import '../../../../core/services/cloud_storage/icloud_storage_provider.dart';
import '../../../../core/services/sync/sync_data_serializer.dart';
import '../../../../core/services/sync/sync_initializer.dart';
import '../../../../core/services/sync/sync_service.dart';
import 'settings_providers.dart';
import 'storage_providers.dart';

/// Sync repository provider
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository();
});

/// Sync data serializer provider
final syncDataSerializerProvider = Provider<SyncDataSerializer>((ref) {
  return SyncDataSerializer();
});

/// Selected cloud provider type
final selectedCloudProviderTypeProvider = StateProvider<CloudProviderType?>((ref) => null);

/// Cloud storage provider singletons
final _googleDriveProvider = GoogleDriveStorageProvider();
final _icloudProvider = ICloudStorageProvider();

/// Cloud storage provider instance (null if none selected or custom folder mode)
///
/// When using custom folder mode, app-managed cloud sync is disabled to prevent
/// conflicts with external sync services (Dropbox, Google Drive desktop, etc.)
final cloudStorageProviderProvider = Provider<CloudStorageProvider?>((ref) {
  // Check if using custom folder mode - disable app-managed sync
  final storageConfigState = ref.watch(storageConfigNotifierProvider);
  if (storageConfigState.config.mode == StorageLocationMode.customFolder) {
    return null; // External sync handles it via the custom folder
  }

  final providerType = ref.watch(selectedCloudProviderTypeProvider);
  if (providerType == null) return null;

  switch (providerType) {
    case CloudProviderType.icloud:
      return _icloudProvider;
    case CloudProviderType.googledrive:
      return _googleDriveProvider;
  }
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    syncRepository: ref.watch(syncRepositoryProvider),
    serializer: ref.watch(syncDataSerializerProvider),
    cloudProvider: ref.watch(cloudStorageProviderProvider),
  );
});

/// Sync status enum
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  hasConflicts,
}

/// Sync state
class SyncState {
  final SyncStatus status;
  final String? message;
  final double? progress;
  final DateTime? lastSync;
  final int pendingChanges;
  final int conflicts;
  final bool isAuthenticated;

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.progress,
    this.lastSync,
    this.pendingChanges = 0,
    this.conflicts = 0,
    this.isAuthenticated = false,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    double? progress,
    DateTime? lastSync,
    int? pendingChanges,
    int? conflicts,
    bool? isAuthenticated,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      lastSync: lastSync ?? this.lastSync,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      conflicts: conflicts ?? this.conflicts,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// Sync state notifier
class SyncNotifier extends StateNotifier<SyncState> {
  final SyncRepository _syncRepository;
  final Ref _ref;
  final _log = LoggerService.forClass(SyncNotifier);

  SyncNotifier(this._syncRepository, this._ref) : super(const SyncState()) {
    _initialize();
  }

  /// Get the current sync service (reads dynamically to get latest cloudProvider)
  SyncService get _syncService => _ref.read(syncServiceProvider);

  Future<void> _initialize() async {
    // Load initial state
    await refreshState();
  }

  void _setupProgressCallback() {
    _syncService.setProgressCallback((progress) {
      state = state.copyWith(
        progress: progress.progress,
        message: progress.message,
      );
    });
  }

  /// Refresh the sync state from the database
  Future<void> refreshState() async {
    try {
      final lastSync = await _syncRepository.getLastSyncTime();
      final pendingCount = await _syncRepository.getPendingCount();
      final conflictCount = await _syncRepository.getConflictCount();
      final isAvailable = await _syncService.isSyncAvailable();

      state = state.copyWith(
        lastSync: lastSync,
        pendingChanges: pendingCount,
        conflicts: conflictCount,
        isAuthenticated: isAvailable,
        status: conflictCount > 0 ? SyncStatus.hasConflicts : SyncStatus.idle,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Failed to load sync state: $e',
      );
    }
  }

  /// Perform a sync operation
  Future<void> performSync() async {
    _log.debug('performSync() called');
    if (state.status == SyncStatus.syncing) {
      _log.debug('Already syncing, returning early');
      return;
    }

    state = state.copyWith(
      status: SyncStatus.syncing,
      message: 'Starting sync...',
      progress: 0.0,
    );

    // Set up progress callback on the current sync service
    _setupProgressCallback();

    _log.debug('Calling _syncService.performSync()...');
    try {
      final result = await _syncService.performSync();
      _log.debug('Result: ${result.status}, message: ${result.message}');

      if (result.isSuccess) {
        state = state.copyWith(
          status: result.conflictsFound > 0
              ? SyncStatus.hasConflicts
              : SyncStatus.success,
          message: result.message ?? 'Sync completed successfully',
          lastSync: result.lastSyncTime,
          conflicts: result.conflictsFound,
          progress: 1.0,
        );
      } else {
        state = state.copyWith(
          status: SyncStatus.error,
          message: result.message ?? 'Sync failed',
          progress: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Sync error: $e',
        progress: null,
      );
    }

    // Refresh state after sync
    await refreshState();
  }

  /// Resolve a conflict
  Future<void> resolveConflict(
    String entityType,
    String recordId,
    ConflictResolution resolution,
  ) async {
    await _syncService.resolveConflict(entityType, recordId, resolution);
    await refreshState();
  }

  /// Sign out from the cloud provider
  Future<void> signOut() async {
    await _syncService.signOut();
    _ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
    // Clear the saved provider from SharedPreferences
    await _ref.read(syncInitializerProvider).saveProvider(null);
    state = const SyncState();
  }

  /// Reset sync state
  Future<void> resetSyncState() async {
    await _syncService.resetSyncState();
    await refreshState();
  }
}

/// Sync state provider
final syncStateProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(
    ref.watch(syncRepositoryProvider),
    ref,
  );
});

/// Last sync time provider (for display)
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(syncStateProvider).lastSync;
});

/// Is sync enabled provider
final isSyncEnabledProvider = Provider<bool>((ref) {
  // Check if cloud sync is disabled due to custom folder mode
  if (ref.watch(isCloudSyncDisabledByCustomFolderProvider)) {
    return false;
  }
  return ref.watch(selectedCloudProviderTypeProvider) != null;
});

/// Whether cloud sync is disabled because custom folder mode is active
final isCloudSyncDisabledByCustomFolderProvider = Provider<bool>((ref) {
  final storageConfigState = ref.watch(storageConfigNotifierProvider);
  return storageConfigState.config.mode == StorageLocationMode.customFolder;
});

/// Pending changes count provider
final pendingChangesCountProvider = Provider<int>((ref) {
  return ref.watch(syncStateProvider).pendingChanges;
});

/// Conflicts count provider
final conflictsCountProvider = Provider<int>((ref) {
  return ref.watch(syncStateProvider).conflicts;
});

/// Is syncing provider
final isSyncingProvider = Provider<bool>((ref) {
  return ref.watch(syncStateProvider).status == SyncStatus.syncing;
});

/// Sync progress provider
final syncProgressProvider = Provider<double?>((ref) {
  return ref.watch(syncStateProvider).progress;
});

/// Sync message provider
final syncMessageProvider = Provider<String?>((ref) {
  return ref.watch(syncStateProvider).message;
});

/// Get conflicts provider
final conflictsProvider = FutureProvider<List<SyncConflict>>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.getConflicts();
});

/// Sync initializer provider
final syncInitializerProvider = Provider<SyncInitializer>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncInitializer(
    syncRepository: ref.watch(syncRepositoryProvider),
    prefs: prefs,
  );
});

/// Sync check on launch provider
/// Returns the result of checking sync status on app launch
final syncLaunchCheckProvider = FutureProvider<SyncCheckResult>((ref) async {
  final initializer = ref.watch(syncInitializerProvider);
  final provider = ref.watch(cloudStorageProviderProvider);
  return initializer.checkSyncOnLaunch(provider);
});

/// Restore last used provider on app launch
final restoreLastProviderProvider = FutureProvider<void>((ref) async {
  final initializer = ref.watch(syncInitializerProvider);
  final lastProvider = initializer.getLastProvider();
  if (lastProvider != null) {
    ref.read(selectedCloudProviderTypeProvider.notifier).state = lastProvider;
  }
});
