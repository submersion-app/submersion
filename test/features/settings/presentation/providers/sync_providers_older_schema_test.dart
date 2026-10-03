import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The real SyncNotifier carries a pull's older-schema peers (issue #2619)
/// into the state that drives the Cloud Sync page's banner, and clears them
/// once the peer catches up.
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

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWithValue('en'),
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
    container.read(syncStateProvider);
    await container.read(syncStateProvider.notifier).refreshState();
    return container;
  }

  test('labels a peer too old to read this device, then clears it', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'peer-dive'),
    );
    await seedPeerLog(cloud, 'stable-ipad-device');
    await restampPeerWriterSchemaVersion(
      cloud,
      'stable-ipad-device',
      writerSchemaVersion: AppDatabase.minimumCompatibleSchemaVersion - 1,
    );
    await restampPeerDeviceName(
      cloud,
      'stable-ipad-device',
      deviceName: 'Stable iPad',
    );
    final container = await makeContainer();
    final notifier = container.read(syncStateProvider.notifier);

    await notifier.performSync();

    expect(container.read(syncStateProvider).olderSchemaPeerLabels, [
      (name: 'Stable iPad', shortId: 'stable-i'),
    ]);

    // The peer updates past the floor; the next sync drops the label.
    await restampPeerWriterSchemaVersion(
      cloud,
      'stable-ipad-device',
      writerSchemaVersion: AppDatabase.currentSchemaVersion,
    );
    await notifier.performSync();

    expect(container.read(syncStateProvider).olderSchemaPeerLabels, isEmpty);
  });
}
