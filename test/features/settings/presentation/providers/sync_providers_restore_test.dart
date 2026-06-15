import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

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
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
    container.read(syncStateProvider);
    await container.read(syncStateProvider.notifier).refreshState();
    return container;
  }

  Future<void> seedLocalDive(String id) async {
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: id));
  }

  group('firstSyncMergeInfo established-provider short-circuit', () {
    test('genuine new device with peers + local dives still gates', () async {
      final container = await makeContainer();
      await seedLocalDive('d1');
      await seedPeerManifest(cloud, 'peer-device');

      final info =
          await container.read(syncStateProvider.notifier).firstSyncMergeInfo();
      expect(
        info,
        isNotNull,
        reason: 'a brand-new device must still confirm before merging',
      );
    });

    test('established provider short-circuits the gate (restore case)',
        () async {
      await EstablishedProviderStore(prefs).add(cloud.providerId);
      final container = await makeContainer();
      await seedLocalDive('d1');
      await seedPeerManifest(cloud, 'peer-device');

      final info =
          await container.read(syncStateProvider.notifier).firstSyncMergeInfo();
      expect(
        info,
        isNull,
        reason:
            'a device that already synced here is not first-contact, even '
            'after a restore wiped its in-DB cursor',
      );
    });
  });

  test('a successful sync anchors the provider and clears the intent',
      () async {
    await PostRestoreSyncStore(prefs).setPending();
    final container = await makeContainer();
    await seedLocalDive('d1');

    await container.read(syncStateProvider.notifier).performSync();

    expect(
      EstablishedProviderStore(prefs).contains(cloud.providerId),
      isTrue,
      reason: 'a clean sync marks this provider established',
    );
    expect(
      PostRestoreSyncStore(prefs).pending,
      isFalse,
      reason: 'the post-restore intent is consumed once a sync succeeds',
    );
  });
}
