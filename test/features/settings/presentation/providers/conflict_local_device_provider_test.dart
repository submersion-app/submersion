import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// The conflict dialog labels the side this device wrote by comparing a row's
/// device id with this device's. Reset Sync State mints a new id, so the
/// provider must not keep the one it resolved before the reset (issue #3029).
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

  ProviderContainer makeContainer({SyncRepository? repo}) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
        if (repo != null) syncRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('reads the device id through syncRepositoryProvider', () async {
    final repo = _FixedIdSyncRepository('overridden-id');
    final container = makeContainer(repo: repo);

    final device = await container.read(conflictLocalDeviceProvider.future);

    expect(device.id, 'overridden-id');
  });

  test('resolves the id again once the dialog stops listening', () async {
    final container = makeContainer();
    final repo = container.read(syncRepositoryProvider);

    final sub = container.listen(conflictLocalDeviceProvider, (_, _) {});
    final before = await container.read(conflictLocalDeviceProvider.future);
    expect(before.id, await repo.getDeviceId());
    sub.close();
    // Let the auto-dispose run, as it does when the dialog closes.
    await Future<void>.delayed(Duration.zero);

    await repo.setDeviceId('new-id-after-reset');

    final after = await container.read(conflictLocalDeviceProvider.future);
    expect(after.id, 'new-id-after-reset');
  });

  test(
    'Reset Sync State refreshes a provider that is still listened to',
    () async {
      final container = makeContainer();
      container.read(syncStateProvider);
      await container.read(syncStateProvider.notifier).refreshState();
      // Let the notifier's initialization settle before the reset.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final sub = container.listen(conflictLocalDeviceProvider, (_, _) {});
      addTearDown(sub.close);
      final before = await container.read(conflictLocalDeviceProvider.future);

      await container.read(syncStateProvider.notifier).resetSyncState();

      final after = await container.read(conflictLocalDeviceProvider.future);
      final current = await container
          .read(syncRepositoryProvider)
          .getDeviceId();
      expect(current, isNot(before.id), reason: 'the reset mints a new id');
      expect(after.id, current);
    },
  );
}

class _FixedIdSyncRepository extends SyncRepository {
  _FixedIdSyncRepository(this.id);

  final String id;

  @override
  Future<String> getDeviceId() async => id;
}
