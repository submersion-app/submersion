import 'dart:async';
import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/library_moved.dart';
import 'package:submersion/core/services/sync/library_moved_store.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';

/// Sync repository provider
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository();
});

/// Sync data serializer provider
final syncDataSerializerProvider = Provider<SyncDataSerializer>((ref) {
  return SyncDataSerializer();
});

/// Runtime iCloud availability for the current build/device. Drives the iCloud
/// provider tile's enabled state and its connection-failure messaging.
final iCloudAvailabilityProvider = FutureProvider<ICloudAvailability>((
  ref,
) async {
  return ICloudNativeService.getAvailability();
});

/// Whether the host is an Apple platform (iOS/macOS), where iCloud can exist at
/// all. Exposed as a provider so the iCloud tile is never enabled on non-Apple
/// platforms (even transiently while [iCloudAvailabilityProvider] loads), and so
/// widget tests can simulate an Apple platform on a non-Apple CI host.
final isApplePlatformProvider = Provider<bool>(
  (ref) => Platform.isIOS || Platform.isMacOS,
);

/// Sync preferences provider
final syncPreferencesProvider = Provider<SyncPreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncPreferences(prefs);
});

/// Library epoch persistence (mirror + pending replace intent).
final libraryEpochStoreProvider = Provider<LibraryEpochStore>((ref) {
  return LibraryEpochStore(ref.watch(sharedPreferencesProvider));
});

/// "Library moved" persistence (acknowledged-move signature + pending
/// old-backend cleanup target) for backend switches.
final libraryMovedStoreProvider = Provider<LibraryMovedStore>((ref) {
  return LibraryMovedStore(ref.watch(sharedPreferencesProvider));
});

/// Merge-restore "sync once on next launch" intent.
final postRestoreSyncStoreProvider = Provider<PostRestoreSyncStore>((ref) {
  return PostRestoreSyncStore(ref.watch(sharedPreferencesProvider));
});

/// Providers this install has successfully synced to (survives restore).
final establishedProviderStoreProvider = Provider<EstablishedProviderStore>((
  ref,
) {
  return EstablishedProviderStore(ref.watch(sharedPreferencesProvider));
});

/// Behavior settings for auto-sync
class SyncBehaviorSettings {
  final bool autoSyncEnabled;
  final bool syncOnLaunch;
  final bool syncOnResume;

  const SyncBehaviorSettings({
    required this.autoSyncEnabled,
    required this.syncOnLaunch,
    required this.syncOnResume,
  });

  SyncBehaviorSettings copyWith({
    bool? autoSyncEnabled,
    bool? syncOnLaunch,
    bool? syncOnResume,
  }) {
    return SyncBehaviorSettings(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncOnLaunch: syncOnLaunch ?? this.syncOnLaunch,
      syncOnResume: syncOnResume ?? this.syncOnResume,
    );
  }
}

class SyncBehaviorNotifier extends StateNotifier<SyncBehaviorSettings> {
  final SyncPreferences _prefs;

  SyncBehaviorNotifier(this._prefs)
    : super(
        SyncBehaviorSettings(
          autoSyncEnabled: _prefs.autoSyncEnabled,
          syncOnLaunch: _prefs.syncOnLaunch,
          syncOnResume: _prefs.syncOnResume,
        ),
      );

  Future<void> setAutoSyncEnabled(bool value) async {
    await _prefs.setAutoSyncEnabled(value);
    state = state.copyWith(autoSyncEnabled: value);
  }

  Future<void> setSyncOnLaunch(bool value) async {
    await _prefs.setSyncOnLaunch(value);
    state = state.copyWith(syncOnLaunch: value);
  }

  Future<void> setSyncOnResume(bool value) async {
    await _prefs.setSyncOnResume(value);
    state = state.copyWith(syncOnResume: value);
  }
}

final syncBehaviorProvider =
    StateNotifierProvider<SyncBehaviorNotifier, SyncBehaviorSettings>((ref) {
      return SyncBehaviorNotifier(ref.watch(syncPreferencesProvider));
    });

/// Selected cloud provider type
final selectedCloudProviderTypeProvider = StateProvider<CloudProviderType?>(
  (ref) => null,
);

/// Cloud storage provider singletons
final _googleDriveProvider = GoogleDriveStorageProvider();
final _icloudProvider = ICloudStorageProvider();
final _s3Provider = S3StorageProvider();

/// The singleton instance backing a [CloudProviderType]. Shared by the active
/// provider resolution and by old-backend cleanup, which must reach a backend
/// the user has already switched away from (so it is no longer the active
/// provider).
CloudStorageProvider cloudProviderInstanceFor(CloudProviderType type) {
  switch (type) {
    case CloudProviderType.icloud:
      return _icloudProvider;
    case CloudProviderType.googledrive:
      return _googleDriveProvider;
    case CloudProviderType.s3:
      return _s3Provider;
  }
}

/// Whether Google Drive can be offered on this platform/build. True on
/// iOS/macOS/Android; on Windows/Linux only when the Desktop-app OAuth
/// client is compiled in (GoogleDriveClientConfig).
final googleDriveAvailableProvider = FutureProvider<bool>((ref) {
  return cloudProviderInstanceFor(CloudProviderType.googledrive).isAvailable();
});

/// Signed-in Google account email for the provider tile subtitle, or null
/// when Google Drive is not the selected provider or no account is known.
/// Watches the authentication flag so connect/sign-out refresh the subtitle
/// without re-running on every sync progress tick.
final googleDriveAccountEmailProvider = FutureProvider<String?>((ref) async {
  final type = ref.watch(selectedCloudProviderTypeProvider);
  if (type != CloudProviderType.googledrive) return null;
  ref.watch(syncStateProvider.select((s) => s.isAuthenticated));
  return cloudProviderInstanceFor(CloudProviderType.googledrive).getUserEmail();
});

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

  return cloudProviderInstanceFor(providerType);
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    syncRepository: ref.watch(syncRepositoryProvider),
    serializer: ref.watch(syncDataSerializerProvider),
    cloudProvider: ref.watch(cloudStorageProviderProvider),
    syncInitializer: ref.watch(syncInitializerProvider),
    epochStore: ref.watch(libraryEpochStoreProvider),
  );
});

/// Sync status enum
enum SyncStatus { idle, syncing, success, error, hasConflicts }

/// Sync state
class SyncState {
  final SyncStatus status;
  final String? message;
  final double? progress;
  final DateTime? lastSync;
  final int pendingChanges;
  final int conflicts;
  final bool isAuthenticated;
  final bool firstSyncAwaitingConfirmation;

  /// True while the one forced post-restore sync is running. Drives the
  /// app-root "Syncing your restored library..." notice; never persisted.
  final bool postRestoreSyncing;

  /// True when the cloud library was replaced from a backup under an epoch
  /// this device has not accepted; sync is paused until the user adopts.
  final bool replaceAwaitingAdoption;

  /// The replacement marker behind [replaceAwaitingAdoption] (who/when).
  final LibraryEpochMarker? replaceMarker;

  /// Non-null when the backend this device is on carries a "library moved"
  /// marker pointing elsewhere that the user has not yet acknowledged -- a
  /// straggler left behind by another device's backend switch. Advisory only:
  /// sync still works, but the banner offers to follow the move.
  final LibraryMovedMarker? movedMarker;

  /// Non-null after the first successful sync on a freshly switched-to backend
  /// when an old backend is still armed for cleanup: the providerId of that
  /// old backend, whose orphaned data the user can now choose to delete.
  final String? cleanupOldBackendProviderId;

  static const Object _messageSentinel = Object();
  static const Object _markerSentinel = Object();
  static const Object _movedSentinel = Object();
  static const Object _cleanupSentinel = Object();

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.progress,
    this.lastSync,
    this.pendingChanges = 0,
    this.conflicts = 0,
    this.isAuthenticated = false,
    this.firstSyncAwaitingConfirmation = false,
    this.postRestoreSyncing = false,
    this.replaceAwaitingAdoption = false,
    this.replaceMarker,
    this.movedMarker,
    this.cleanupOldBackendProviderId,
  });

  SyncState copyWith({
    SyncStatus? status,
    Object? message = _messageSentinel,
    double? progress,
    DateTime? lastSync,
    int? pendingChanges,
    int? conflicts,
    bool? isAuthenticated,
    bool? firstSyncAwaitingConfirmation,
    bool? postRestoreSyncing,
    bool? replaceAwaitingAdoption,
    Object? replaceMarker = _markerSentinel,
    Object? movedMarker = _movedSentinel,
    Object? cleanupOldBackendProviderId = _cleanupSentinel,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: identical(message, _messageSentinel)
          ? this.message
          : message as String?,
      progress: progress ?? this.progress,
      lastSync: lastSync ?? this.lastSync,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      conflicts: conflicts ?? this.conflicts,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      firstSyncAwaitingConfirmation:
          firstSyncAwaitingConfirmation ?? this.firstSyncAwaitingConfirmation,
      postRestoreSyncing: postRestoreSyncing ?? this.postRestoreSyncing,
      replaceAwaitingAdoption:
          replaceAwaitingAdoption ?? this.replaceAwaitingAdoption,
      replaceMarker: identical(replaceMarker, _markerSentinel)
          ? this.replaceMarker
          : replaceMarker as LibraryEpochMarker?,
      movedMarker: identical(movedMarker, _movedSentinel)
          ? this.movedMarker
          : movedMarker as LibraryMovedMarker?,
      cleanupOldBackendProviderId:
          identical(cleanupOldBackendProviderId, _cleanupSentinel)
          ? this.cleanupOldBackendProviderId
          : cleanupOldBackendProviderId as String?,
    );
  }
}

/// What the first sync would combine: shown to the user before the first
/// library-merging sync is allowed to run.
class FirstSyncMergeInfo {
  final int peerFileCount;
  final int localDiveCount;

  const FirstSyncMergeInfo({
    required this.peerFileCount,
    required this.localDiveCount,
  });
}

/// Sync state notifier
class SyncNotifier extends StateNotifier<SyncState> {
  final SyncRepository _syncRepository;
  final Ref _ref;
  final _log = LoggerService.forClass(SyncNotifier);
  StreamSubscription<void>? _changeSubscription;
  Timer? _autoSyncTimer;
  bool _syncInFlight = false;

  SyncNotifier(this._syncRepository, this._ref) : super(const SyncState()) {
    _initialize();
    _listenForChanges();
  }

  /// Get the current sync service (reads dynamically to get latest cloudProvider)
  SyncService get _syncService => _ref.read(syncServiceProvider);

  Future<void> _initialize() async {
    if (!mounted) return;
    // Restore the saved provider before reading sync state: restoreLastProvider
    // is async, so without awaiting it _initialize can race ahead and read a
    // null provider, skipping the post-restore intent and replaced-library
    // surfacing for the whole session. Mirrors _maybeSyncOnLaunch awaiting
    // reconcileDeviceIdentityProvider.
    try {
      await _ref.read(restoreLastProviderProvider.future);
    } catch (_) {
      // Non-fatal: proceed with whatever provider state exists.
    }
    if (!mounted) return;
    await refreshState();
    if (!mounted) return;

    // Every post-restore intent below needs a cloud provider. Without one, a
    // persisted Replace intent would drive performSync() into a "no provider
    // configured" error state on launch -- even for users who never enabled
    // cloud sync. Keep the intent dormant until a provider exists; it survives
    // in libraryEpochStore for a later launch that has one.
    final provider = _ref.read(cloudStorageProviderProvider);
    if (provider == null) return;

    // A Replace restore persists its cloud side as a pending intent; execute
    // it as soon as the app is back up, regardless of auto-sync settings.
    if (_ref.read(libraryEpochStoreProvider).pendingReplace != null) {
      unawaited(performSync());
      return;
    }

    // A Merge restore persists a post-restore intent: the restore dialog's
    // Merge choice is the consent, so force one sync that bypasses the
    // first-contact gate (auto:false) regardless of the auto-sync toggles.
    if (_ref.read(postRestoreSyncStoreProvider).pending) {
      unawaited(_runPostRestoreSync());
      return;
    }

    // On the other devices, surface a Replace-everywhere adoption proactively
    // (even with auto-sync off) so a paused device is never hidden behind a
    // manual Sync Now.
    unawaited(_detectReplacedLibraryForSurfacing());
  }

  /// Force the one consented post-restore sync. `performSync(auto:false)` skips
  /// the first-contact gate; the success path clears the intent.
  Future<void> _runPostRestoreSync() async {
    if (!mounted) return;
    state = state.copyWith(postRestoreSyncing: true);
    await performSync();
    if (mounted) state = state.copyWith(postRestoreSyncing: false);
  }

  /// On a device that did NOT restore, surface a Replace-everywhere adoption
  /// proactively -- even with auto-sync off -- so the pause is never hidden
  /// behind a manual Sync Now. Detection only; the destructive adopt stays
  /// behind the confirmation dialog.
  Future<void> _detectReplacedLibraryForSurfacing() async {
    final marker = await libraryReplaceInfo();
    if (marker == null || !mounted) return;
    // Surface only -- never sync from here. Only devices that HOLD dives pause
    // and need the unmissable prompt; an empty device has nothing to lose and
    // auto-adopts through performSync's own awaiting-adoption path on its next
    // sync. Syncing from a detection hook would also race other launch-time
    // syncs (and test setups), so detection stays pure: read marker, set state.
    final diveCount = await _ref.read(diveRepositoryProvider).getDiveCount();
    if (!mounted || diveCount == 0) return;
    state = state.copyWith(
      replaceAwaitingAdoption: true,
      replaceMarker: marker,
    );
  }

  void _listenForChanges() {
    _changeSubscription = SyncEventBus.changes.listen((_) {
      _scheduleAutoSync();
    });
  }

  void _scheduleAutoSync() {
    final settings = _ref.read(syncBehaviorProvider);
    if (!settings.autoSyncEnabled) return;
    if (state.status == SyncStatus.syncing) return;

    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(const Duration(seconds: 5), () {
      performSync(auto: true);
    });
  }

  void _setupProgressCallback() {
    _syncService.setProgressCallback((progress) {
      // A launch-triggered sync can outlive this notifier (container torn
      // down mid-upload); progress ticks must not touch a disposed notifier.
      if (!mounted) return;
      state = state.copyWith(
        progress: progress.progress,
        message: progress.message,
      );
    });
  }

  /// Refresh the sync state from the database
  Future<void> refreshState() async {
    try {
      // Scope the displayed "last synced" to the active backend: after a
      // switch, showing the cursor from the old backend would claim we are
      // synced with a backend we have never contacted.
      final activeProvider = _ref.read(cloudStorageProviderProvider);
      final lastSync = await _syncRepository.getLastSyncTime(
        forProvider: activeProvider?.providerId,
      );
      final pendingCount = await _syncRepository.getPendingCount();
      final conflictCount = await _syncRepository.getConflictCount();
      final isAvailable = await _syncService.isSyncAvailable();

      if (!mounted) return;
      state = state.copyWith(
        lastSync: lastSync,
        pendingChanges: pendingCount,
        conflicts: conflictCount,
        isAuthenticated: isAvailable,
        status: conflictCount > 0 ? SyncStatus.hasConflicts : SyncStatus.idle,
        message: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Failed to load sync state: $e',
      );
    }
  }

  /// Non-null when the NEXT sync would be this device's first contact with
  /// existing cloud data while this device already holds dives -- the case
  /// where a sync irreversibly combines two libraries (and duplicates any
  /// dives that were imported separately on each device). The UI must
  /// confirm before running that sync; auto-sync defers it entirely.
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async {
    try {
      final provider = _ref.read(cloudStorageProviderProvider);
      if (provider == null) return null;
      // An established device is never first-contact: a restore wipes the
      // in-DB cursor (lastSyncTime), but this anchor survives, so the gate
      // must not re-fire for a device that already merged here.
      if (_ref
          .read(establishedProviderStoreProvider)
          .contains(provider.providerId)) {
        return null;
      }
      // Scoped: first contact is per-backend. A cursor minted against a
      // backend the user switched away from must not mask the first,
      // library-combining sync against the new one.
      final lastSync = await _syncRepository.getLastSyncTime(
        forProvider: provider.providerId,
      );
      if (lastSync != null) return null;
      final localDives = await _ref.read(diveRepositoryProvider).getDiveCount();
      if (localDives == 0) return null;
      final peers = await _ref
          .read(syncInitializerProvider)
          .peerSyncFiles(provider)
          .timeout(const Duration(seconds: 8));
      if (peers.isEmpty) return null;
      return FirstSyncMergeInfo(
        peerFileCount: peers.length,
        localDiveCount: localDives,
      );
    } catch (e) {
      // The guard must never block sync outright; on failure fall through
      // to normal behavior.
      _log.warning('First-contact check failed: $e');
      return null;
    }
  }

  /// Non-null when the cloud library was replaced under an epoch this device
  /// has not accepted -- the next sync would halt for adoption. Mirrors the
  /// [firstSyncMergeInfo] pre-check pattern for the Sync Now button.
  Future<LibraryEpochMarker?> libraryReplaceInfo() async {
    try {
      final provider = _ref.read(cloudStorageProviderProvider);
      if (provider == null) return null;
      final store = _ref.read(libraryEpochStoreProvider);
      if (store.pendingReplace != null) return null; // we ARE the replacer
      final marker = await _syncService
          .readLibraryEpochMarker(provider)
          .timeout(const Duration(seconds: 8));
      if (marker == null) return null;
      final accepted =
          await _syncRepository.getLastAcceptedEpochId() ??
          store.lastAcceptedEpochId;
      if (marker.epochId == accepted) return null;
      return marker;
    } catch (e) {
      // Never block the button on this pre-check; performSync gates anyway.
      _log.warning('Library replace pre-check failed: $e');
      return null;
    }
  }

  /// After a successful sync, if an old backend is armed for cleanup and we
  /// just synced against a DIFFERENT backend, surface the cleanup offer. The
  /// different-backend guard means the first real sync on the new backend has
  /// landed -- only then is deleting the old copy safe.
  Future<void> _surfaceOldBackendCleanupOffer() async {
    final pending = _ref.read(libraryMovedStoreProvider).pendingCleanup;
    if (pending == null) return;
    final active = _ref.read(cloudStorageProviderProvider);
    if (active == null || active.providerId == pending) return;
    if (!mounted) return;
    state = state.copyWith(cleanupOldBackendProviderId: pending);
  }

  /// Record this device leaving [oldProvider] for the backend [toProviderId].
  /// Called when the user confirms a backend switch, BEFORE the active
  /// provider selection changes (so [oldProvider] is still reachable):
  ///
  /// - stamps the (possibly legacy/unstamped) cursor for the old backend, so
  ///   it cannot read as "synced here" against the new one;
  /// - leaves a "library moved" marker on the old backend so a straggler still
  ///   pointed there learns where the library went instead of syncing into an
  ///   abandoned copy forever;
  /// - arms the old backend for optional cleanup after the first successful
  ///   sync on the new one.
  ///
  /// All steps are best-effort: a switch must never be blocked by the old
  /// backend being unreachable.
  Future<void> recordBackendDeparture({
    required CloudStorageProvider oldProvider,
    required String toProviderId,
    String? toProviderName,
  }) async {
    final oldId = oldProvider.providerId;
    try {
      await _syncRepository.stampLegacyCursorProvider(oldId);
    } catch (e) {
      _log.warning('Could not stamp cursor for old backend $oldId: $e');
    }

    final meta = await _deviceMetadata();
    final marker = LibraryMovedMarker(
      movedAt: DateTime.now().millisecondsSinceEpoch,
      toProviderId: toProviderId,
      toProviderName: toProviderName,
      deviceId: meta.$1,
      deviceName: meta.$2,
      appVersion: meta.$3,
    );
    await _syncService.writeLibraryMovedMarker(oldProvider, marker);
    await _ref.read(libraryMovedStoreProvider).setPendingCleanup(oldId);
    _log.info('Recorded backend departure $oldId -> $toProviderId');
  }

  /// Network pre-check: does the backend we are on carry a "moved" marker
  /// pointing at a DIFFERENT backend that we have not acknowledged? If so,
  /// surface it; the banner offers to follow the move. Never throws.
  Future<void> checkLibraryMoved() async {
    try {
      final provider = _ref.read(cloudStorageProviderProvider);
      if (provider == null) return;
      final marker = await _syncService.readLibraryMovedMarker(provider);
      if (!mounted) return;
      final store = _ref.read(libraryMovedStoreProvider);
      // A marker pointing at the backend we are already on is not a move away
      // from us; ignore it. So is one the user already dismissed.
      if (marker == null ||
          marker.toProviderId == provider.providerId ||
          store.isAcknowledged(marker)) {
        if (state.movedMarker != null) {
          state = state.copyWith(movedMarker: null);
        }
        return;
      }
      state = state.copyWith(movedMarker: marker);
    } catch (e) {
      _log.warning('Library moved pre-check failed: $e');
    }
  }

  /// Dismiss the "library moved" banner and remember the dismissal so the
  /// same move does not re-notify on the next sync.
  Future<void> acknowledgeMoved() async {
    final marker = state.movedMarker;
    if (marker != null) {
      await _ref.read(libraryMovedStoreProvider).acknowledge(marker);
    }
    if (!mounted) return;
    state = state.copyWith(movedMarker: null);
  }

  /// Delete the orphaned data left on a backend the user switched away from,
  /// in response to the post-switch cleanup offer. Best-effort; clears the
  /// offer regardless so it is not presented again.
  Future<void> cleanupOldBackendData() async {
    final id = state.cleanupOldBackendProviderId;
    final store = _ref.read(libraryMovedStoreProvider);
    if (id != null) {
      try {
        final type = CloudProviderType.values.firstWhere((t) => t.name == id);
        await _syncService.cleanupOldBackend(cloudProviderInstanceFor(type));
      } catch (e) {
        _log.warning('Old-backend cleanup failed for $id: $e');
      }
    }
    await store.clearPendingCleanup();
    if (!mounted) return;
    state = state.copyWith(cleanupOldBackendProviderId: null);
  }

  /// Decline the post-switch cleanup offer: leave the old backend's data in
  /// place (the user may still want it) and stop offering.
  Future<void> dismissOldBackendCleanup() async {
    await _ref.read(libraryMovedStoreProvider).clearPendingCleanup();
    if (!mounted) return;
    state = state.copyWith(cleanupOldBackendProviderId: null);
  }

  /// Device identity for a marker: (deviceId, deviceName, appVersion). Each
  /// piece degrades to a safe default; markers are shown in banners so the
  /// origin must always be displayable.
  Future<(String, String?, String?)> _deviceMetadata() async {
    String deviceId;
    try {
      deviceId = await _syncRepository.getDeviceId();
    } catch (_) {
      deviceId = 'unknown';
    }
    String? deviceName;
    try {
      deviceName = Platform.localHostname;
    } catch (_) {
      deviceName = null;
    }
    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      appVersion = null;
    }
    return (deviceId, deviceName, appVersion);
  }

  /// Adopt the replaced cloud library. The CALLER is responsible for the
  /// safety backup (cloud_sync_page runs it via backupServiceProvider to
  /// avoid a provider import cycle). Ends with a follow-up sync that uploads
  /// this device's freshly stamped file.
  Future<void> adoptReplacedLibrary() async {
    if (_syncInFlight || state.status == SyncStatus.syncing) return;
    state = state.copyWith(
      status: SyncStatus.syncing,
      message: 'Adopting the restored library...',
    );
    final result = await _syncService.adoptReplacedLibrary();
    if (!result.isSuccess) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: result.message ?? 'Failed to adopt the restored library',
      );
      return;
    }
    await realignActiveDiverAfterDataReplace(
      _ref.read(sharedPreferencesProvider),
    );
    state = state.copyWith(
      status: SyncStatus.idle,
      replaceAwaitingAdoption: false,
      replaceMarker: null,
      message: null,
    );
    await performSync();
  }

  /// Perform a sync operation.
  ///
  /// [auto] marks unattended triggers (launch, resume, post-write debounce).
  /// An auto sync defers this device's FIRST library-combining contact to a
  /// manual, user-confirmed Sync Now instead of merging unannounced.
  Future<void> performSync({bool auto = false}) async {
    _log.debug('performSync() called');
    if (_syncInFlight || state.status == SyncStatus.syncing) {
      _log.debug('Already syncing, returning early');
      return;
    }
    _syncInFlight = true;
    try {
      if (auto) {
        final info = await firstSyncMergeInfo();
        if (info != null) {
          _log.info(
            'Deferring auto sync: first contact with existing cloud data '
            'needs user confirmation',
          );
          state = state.copyWith(
            firstSyncAwaitingConfirmation: true,
            message: 'First sync needs confirmation. Tap Sync Now to review.',
          );
          return;
        }
      }

      state = state.copyWith(
        status: SyncStatus.syncing,
        message: 'Starting sync...',
        progress: 0.0,
        firstSyncAwaitingConfirmation: false,
        replaceAwaitingAdoption: false,
        replaceMarker: null,
      );

      // Set up progress callback on the current sync service
      _setupProgressCallback();

      _log.debug('Calling _syncService.performSync()...');
      try {
        var result = await _syncService.performSync();
        _log.debug('Result: ${result.status}, message: ${result.message}');
        // This notifier can be disposed while a launch-triggered sync is in
        // flight; never touch state after an await without re-checking.
        if (!mounted) return;

        if (result.status == SyncResultStatus.awaitingAdoption) {
          final diveCount = await _ref
              .read(diveRepositoryProvider)
              .getDiveCount();
          if (!mounted) return;
          if (diveCount == 0) {
            // Nothing local to lose: adopt silently, like an empty device
            // joining sync, then run the normal sync to upload our file.
            final adopt = await _syncService.adoptReplacedLibrary();
            if (adopt.isSuccess) {
              await realignActiveDiverAfterDataReplace(
                _ref.read(sharedPreferencesProvider),
              );
              result = await _syncService.performSync();
            } else {
              result = adopt;
            }
            if (!mounted) return;
          } else {
            state = state.copyWith(
              status: SyncStatus.idle,
              replaceAwaitingAdoption: true,
              replaceMarker: result.replaceMarker,
              message:
                  'Sync paused: the library was replaced from a backup. '
                  'Tap Sync Now to review.',
              progress: null,
            );
            return;
          }
        }

        if (result.isSuccess) {
          final defaultMessage = result.conflictsFound > 0
              ? 'Sync completed with conflicts'
              : 'Sync completed successfully';
          state = state.copyWith(
            status: result.conflictsFound > 0
                ? SyncStatus.hasConflicts
                : SyncStatus.success,
            message: result.message ?? defaultMessage,
            lastSync: result.lastSyncTime,
            conflicts: result.conflictsFound,
            progress: 1.0,
          );
          // Mark this provider established and consume any post-restore intent:
          // a future restore that wipes the in-DB cursor must not make this
          // device look like first-contact again, and the Merge restore's
          // one-shot intent is now satisfied.
          final syncedProvider = _ref.read(cloudStorageProviderProvider);
          if (syncedProvider != null) {
            await _ref
                .read(establishedProviderStoreProvider)
                .add(syncedProvider.providerId);
          }
          await _ref.read(postRestoreSyncStoreProvider).clear();
          await _surfaceOldBackendCleanupOffer();
          // A straggler syncing into a backend another device moved away from
          // learns of the move here -- the moment it is actively writing into
          // the now-orphaned copy.
          await checkLibraryMoved();
        } else {
          state = state.copyWith(
            status: SyncStatus.error,
            message: result.message ?? 'Sync failed',
            progress: null,
          );
        }
      } catch (e) {
        if (!mounted) return;
        final phase = state.message ?? 'sync';
        state = state.copyWith(
          status: SyncStatus.error,
          message: 'Sync error during $phase: $e',
          progress: null,
        );
      }

      // Refresh state after a brief delay so status is readable.
      if (state.status == SyncStatus.success ||
          state.status == SyncStatus.hasConflicts) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        await refreshState();
      }
    } finally {
      _syncInFlight = false;
    }
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
  ///
  /// For S3 the credentials are hand-entered, so disconnecting only
  /// deselects the provider; the stored configuration survives and the
  /// S3 settings page offers the explicit, destructive
  /// "Remove Configuration" instead.
  Future<void> signOut() async {
    final selected = _ref.read(selectedCloudProviderTypeProvider);
    if (selected != CloudProviderType.s3) {
      await _syncService.signOut();
    } else {
      // Match SyncService.signOut()'s metadata clearing without the
      // provider sign-out, so the hand-entered credentials survive.
      await _syncRepository.setCloudProvider(null);
      await _syncRepository.setRemoteFileId(null);
    }
    _ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
    // Clear the saved provider from SharedPreferences
    await _ref.read(syncInitializerProvider).saveProvider(null);
    // The S3 tile watches this; a sign-out (or future config change) must
    // not leave it showing stale state.
    _ref.invalidate(s3ConfigProvider);
    state = const SyncState();
  }

  /// Reset sync state
  ///
  /// Also adopts a brand-new device identity. Reset is the user-facing
  /// recovery for sync gone wrong, and the worst such state -- two installs
  /// syncing as the same device after cross-device restores -- is only
  /// fixable with a fresh identity. Restore detection deliberately preserves
  /// the anchored identity, so a clone survives everything short of this.
  /// The retired identity's cloud file is removed best-effort: after the id
  /// changes it would otherwise be merged back as a stale "peer" forever.
  Future<void> resetSyncState() async {
    final oldDeviceId = await _syncRepository.getDeviceId();
    await _syncService.resetSyncState();
    await _ref.read(syncInitializerProvider).adoptFreshIdentity();
    await _syncService.deleteDeviceSyncFile(oldDeviceId);
    // Reset is the manual escape hatch: drop any stuck replace intent and
    // un-pause an awaiting-adoption state.
    await _ref.read(libraryEpochStoreProvider).clearPendingReplace();
    await _ref.read(postRestoreSyncStoreProvider).clear();
    await _ref.read(establishedProviderStoreProvider).clear();
    state = state.copyWith(replaceAwaitingAdoption: false, replaceMarker: null);
    await refreshState();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _changeSubscription?.cancel();
    super.dispose();
  }
}

/// Sync state provider
final syncStateProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref.watch(syncRepositoryProvider), ref);
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

/// Reconcile the sync device identity on app launch.
///
/// Detects a database restore -- the on-disk database no longer matches the
/// anchors mirrored outside it: a rotated instance token (the primary signal,
/// which catches a same-device backup) or the device id -- and re-baselines
/// sync so a rewound baseline can't stall sync or resurrect deletes. Runs
/// unconditionally at startup, independent of whether a cloud provider is
/// configured. See [SyncInitializer.reconcileDeviceIdentity].
final reconcileDeviceIdentityProvider = FutureProvider<DeviceIdentityStatus>((
  ref,
) async {
  final initializer = ref.watch(syncInitializerProvider);
  return initializer.reconcileDeviceIdentity();
});

/// Restore last used provider on app launch
final restoreLastProviderProvider = FutureProvider<void>((ref) async {
  final initializer = ref.watch(syncInitializerProvider);
  final lastProvider = initializer.getLastProvider();
  if (lastProvider != null) {
    // Defer mutation to avoid changing provider state during initialization.
    await Future<void>.microtask(() {
      ref.read(selectedCloudProviderTypeProvider.notifier).state = lastProvider;
    });
  }
});

/// Direct access to the S3 provider singleton for the configuration UI
/// (load/save config, test connection).
final s3StorageProviderInstanceProvider = Provider<S3StorageProvider>(
  (ref) => _s3Provider,
);

/// The stored S3 configuration, or null when S3 has not been set up.
/// Invalidate after saving or removing the configuration.
final s3ConfigProvider = FutureProvider<S3Config?>((ref) async {
  return ref.watch(s3StorageProviderInstanceProvider).loadConfig();
});
