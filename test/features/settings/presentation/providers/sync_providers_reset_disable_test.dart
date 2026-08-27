import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/sync/sync_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// Fails when asked to disable auto-sync, to exercise the independent-guard
/// path in [SyncNotifier.disableForDatabaseReset].
class _ThrowingBehaviorNotifier extends SyncBehaviorNotifier {
  _ThrowingBehaviorNotifier(super.prefs);

  @override
  Future<void> setAutoSyncEnabled(bool value) async =>
      throw StateError('setAutoSyncEnabled failed');
}

/// Coverage for the REAL SyncNotifier.disableForDatabaseReset() -- the guard
/// that stops a database reset from being immediately undone by the launch
/// sync re-pulling the cloud library. The storage-settings widget tests use a
/// fake notifier, so the real method is only exercised here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cloud = FakeCloudStorageProvider();
  });

  tearDown(tearDownTestDatabase);

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
    container.read(syncStateProvider);
    await container.read(syncStateProvider.notifier).refreshState();
    return container;
  }

  test(
    'disables auto-sync and signs out so a reset is not re-pulled',
    () async {
      final container = await makeContainer();
      await container
          .read(syncBehaviorProvider.notifier)
          .setAutoSyncEnabled(true);
      container.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.icloud;

      await container
          .read(syncStateProvider.notifier)
          .disableForDatabaseReset();

      // Auto-sync off closes the launch/resume re-pull path...
      expect(container.read(syncBehaviorProvider).autoSyncEnabled, isFalse);
      // ...and the provider is disconnected so a manual sync cannot pull.
      expect(container.read(selectedCloudProviderTypeProvider), isNull);
    },
  );

  test(
    'still signs out (and rethrows) when disabling auto-sync throws',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudStorageProviderProvider.overrideWithValue(cloud),
          syncBehaviorProvider.overrideWith(
            (ref) => _ThrowingBehaviorNotifier(SyncPreferences(prefs)),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(syncStateProvider);
      await container.read(syncStateProvider.notifier).refreshState();
      container.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.icloud;

      // The first guard throws, but the second must still run, and the failure
      // must surface so the caller can log it.
      await expectLater(
        container.read(syncStateProvider.notifier).disableForDatabaseReset(),
        throwsA(isA<StateError>()),
      );
      expect(container.read(selectedCloudProviderTypeProvider), isNull);
    },
  );
}
