import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Minimal fake [SyncNotifier] whose state the test can drive directly, so
/// the email provider's dependency on the sync state can be pinned without
/// the real notifier's database/cloud wiring.
///
/// These tests only ever read `state` and push new values through [emit];
/// no notifier method is called. The rest of SyncNotifier's large and still
/// growing surface is routed through [noSuchMethod] rather than stubbed
/// member by member, so adding a method to the real notifier does not break
/// this file (it did exactly that seven times before this was changed).
class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier(super.state);

  void emit(SyncState newState) => state = newState;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  test(
    'googleDriveAccountEmailProvider is null while not authenticated',
    () async {
      // A revoked grant leaves GoogleSignInAuthenticator._currentUser set on
      // purpose, so getUserEmail() still returns an address. The provider must
      // gate on the auth flag or the tile advertises an account that cannot
      // sync. Regression guard for the PR #1105 review.
      final container = ProviderContainer(
        overrides: [
          selectedCloudProviderTypeProvider.overrideWith(
            (ref) => CloudProviderType.googledrive,
          ),
          syncStateProvider.overrideWith(
            (ref) => _FakeSyncNotifier(const SyncState(isAuthenticated: false)),
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
