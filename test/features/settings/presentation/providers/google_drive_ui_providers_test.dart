import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/sync_service.dart'
    show ConflictResolution;
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Minimal fake [SyncNotifier] whose state the test can drive directly, so
/// the email provider's dependency on the sync state can be pinned without
/// the real notifier's database/cloud wiring. Mirrors the `_FakeSyncNotifier`
/// pattern in `cloud_sync_page_test.dart`.
class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier(super.state);

  void emit(SyncState newState) => state = newState;

  @override
  Future<void> performSync({bool auto = false}) async {}

  @override
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async => null;

  @override
  Future<LibraryEpochMarker?> libraryReplaceInfo() async => null;

  @override
  Future<void> adoptReplacedLibrary() async {}

  @override
  Future<void> acknowledgeMoved() async {}

  @override
  Future<void> checkLibraryMoved() async {}

  @override
  Future<void> cleanupOldBackendData() async {}

  @override
  Future<void> dismissOldBackendCleanup() async {}

  @override
  Future<void> recordBackendDeparture({
    required CloudStorageProvider oldProvider,
    required String toProviderId,
    String? toProviderName,
  }) async {}

  @override
  Future<void> refreshState() async {}

  @override
  Future<void> resetSyncState() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resolveConflict(
    String entityType,
    String recordId,
    ConflictResolution resolution,
  ) async {}
}

void main() {
  test(
    'googleDriveAccountEmailProvider is null when Drive not selected',
    () async {
      final container = ProviderContainer(
        overrides: [
          selectedCloudProviderTypeProvider.overrideWith(
            (ref) => CloudProviderType.icloud,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(googleDriveAccountEmailProvider.future),
        isNull,
      );
    },
  );

  test(
    'googleDriveAvailableProvider resolves without authentication',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Must not throw and must not require sign-in; the exact value is
      // platform-dependent (config-gated on Windows/Linux, true elsewhere).
      expect(
        await container.read(googleDriveAvailableProvider.future),
        isA<bool>(),
      );
    },
  );

  test('googleDriveAccountEmailProvider recomputes on isAuthenticated flips '
      'but not on progress ticks', () async {
    var syncState = const SyncState();
    final fakeSync = _FakeSyncNotifier(syncState);
    final container = ProviderContainer(
      overrides: [
        selectedCloudProviderTypeProvider.overrideWith(
          (ref) => CloudProviderType.googledrive,
        ),
        syncStateProvider.overrideWith((ref) => fakeSync),
      ],
    );
    addTearDown(container.dispose);

    // Every recompute of the FutureProvider emits a loading cycle;
    // counting those pins exactly when the provider re-runs.
    var loadCycles = 0;
    container.listen<AsyncValue<String?>>(googleDriveAccountEmailProvider, (
      previous,
      next,
    ) {
      if (next.isLoading) loadCycles++;
    }, fireImmediately: true);
    await container.read(googleDriveAccountEmailProvider.future);
    expect(loadCycles, 1, reason: 'initial load only');

    // A progress-only tick (what performSync emits continuously during a
    // sync) must NOT re-run getUserEmail(); this fails if the provider
    // watches the whole SyncState instead of selecting isAuthenticated.
    fakeSync.emit(syncState = syncState.copyWith(progress: 0.5));
    await Future<void>.delayed(Duration.zero);
    await container.read(googleDriveAccountEmailProvider.future);
    expect(loadCycles, 1, reason: 'progress tick must not recompute');

    // Flipping the authentication flag (connect/sign-out) MUST recompute;
    // this fails if the syncStateProvider watch line is removed entirely.
    fakeSync.emit(syncState = syncState.copyWith(isAuthenticated: true));
    await Future<void>.delayed(Duration.zero);
    await container.read(googleDriveAccountEmailProvider.future);
    expect(loadCycles, 2, reason: 'auth flip must recompute');
  });
}
