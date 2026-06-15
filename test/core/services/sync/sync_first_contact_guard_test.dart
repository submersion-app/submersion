import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Future<ProviderContainer> makeContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final cloud = FakeCloudStorageProvider();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
    // Trigger notifier construction and wait for _initialize() ->
    // refreshState() to complete, so its async DB reads do not race with
    // performSync state assertions.
    container.read(syncStateProvider);
    await container.read(syncStateProvider.notifier).refreshState();
    return container;
  }

  Future<void> seedLocalDive(String id) async {
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: id));
  }

  group('first-contact merge guard', () {
    test('firstSyncMergeInfo reports peers and local dives', () async {
      final container = await makeContainer();
      final cloud =
          container.read(cloudStorageProviderProvider)
              as FakeCloudStorageProvider;

      await seedLocalDive('local-1');
      await seedPeerManifest(cloud, 'peer-device');

      final info = await container
          .read(syncStateProvider.notifier)
          .firstSyncMergeInfo();

      expect(info, isNotNull);
      expect(info!.peerFileCount, 1);
      expect(info.localDiveCount, 1);
    });

    test('returns null once a baseline exists', () async {
      final container = await makeContainer();
      final cloud =
          container.read(cloudStorageProviderProvider)
              as FakeCloudStorageProvider;

      await seedLocalDive('local-2');
      await seedPeerManifest(cloud, 'peer-device');
      await SyncRepository().updateLastSyncTime(DateTime(2026, 1, 1));

      final info = await container
          .read(syncStateProvider.notifier)
          .firstSyncMergeInfo();

      expect(info, isNull, reason: 'the guard protects only the FIRST contact');
    });

    test('fires again when the cursor was minted against a different '
        'backend', () async {
      final container = await makeContainer();
      final cloud =
          container.read(cloudStorageProviderProvider)
              as FakeCloudStorageProvider;

      await seedLocalDive('local-7');
      await seedPeerManifest(cloud, 'peer-device');
      // The device synced before -- but against the backend it just switched
      // away from. For THIS backend the next sync is still first contact.
      await SyncRepository().updateLastSyncTime(
        DateTime(2026, 1, 1),
        providerId: 'old-backend',
      );

      final info = await container
          .read(syncStateProvider.notifier)
          .firstSyncMergeInfo();

      expect(
        info,
        isNotNull,
        reason:
            'a cursor carried over from another backend must not mask first '
            'contact with this one -- that bypass silently merges whatever '
            'library lives on the new backend',
      );
    });

    test('returns null with no local data', () async {
      final container = await makeContainer();
      final cloud =
          container.read(cloudStorageProviderProvider)
              as FakeCloudStorageProvider;

      await seedPeerManifest(cloud, 'peer-device');

      final info = await container
          .read(syncStateProvider.notifier)
          .firstSyncMergeInfo();

      expect(
        info,
        isNull,
        reason:
            'merging into an empty library is a plain download -- '
            'no confirmation needed',
      );
    });

    test('returns null with no peers', () async {
      final container = await makeContainer();

      await seedLocalDive('local-3');

      final info = await container
          .read(syncStateProvider.notifier)
          .firstSyncMergeInfo();

      expect(info, isNull);
    });

    test('auto sync defers on first contact instead of merging', () async {
      final container = await makeContainer();
      final cloud =
          container.read(cloudStorageProviderProvider)
              as FakeCloudStorageProvider;

      await seedLocalDive('local-4');
      await seedPeerManifest(cloud, 'peer-device');
      final filesBefore = cloud.fileCount;

      await container.read(syncStateProvider.notifier).performSync(auto: true);

      final state = container.read(syncStateProvider);
      expect(state.firstSyncAwaitingConfirmation, isTrue);
      expect(
        cloud.fileCount,
        filesBefore,
        reason: 'no upload may happen before the user confirms the merge',
      );
    });

    test('concurrent triggers run exactly one sync', () async {
      final container = await makeContainer();
      final cloud =
          container.read(cloudStorageProviderProvider)
              as FakeCloudStorageProvider;

      await seedLocalDive('local-6');
      // No peer files: neither trigger defers, both want a real sync.
      final notifier = container.read(syncStateProvider.notifier);

      await Future.wait([
        notifier.performSync(auto: true),
        notifier.performSync(),
      ]);

      final manifestPublishes = cloud.operationLog
          .where((o) => o.startsWith('upload:') && o.contains('.manifest.json'))
          .length;
      expect(
        manifestPublishes,
        1,
        reason:
            'simultaneous triggers must collapse into one sync -- two '
            'concurrent publishes to the same per-device manifest is the '
            'conflicted-copy race the per-device logs exist to prevent',
      );
    });

    test('manual sync proceeds and clears the deferred flag', () async {
      final container = await makeContainer();
      final cloud =
          container.read(cloudStorageProviderProvider)
              as FakeCloudStorageProvider;

      await seedLocalDive('local-5');
      await seedPeerManifest(cloud, 'peer-device');
      await container.read(syncStateProvider.notifier).performSync(auto: true);

      await container.read(syncStateProvider.notifier).performSync();

      final state = container.read(syncStateProvider);
      expect(state.firstSyncAwaitingConfirmation, isFalse);
      final deviceId = await SyncRepository().getDeviceId();
      expect(
        await hasPublishedLog(cloud, deviceId),
        isTrue,
        reason: 'the manual (user-confirmed) path performs the sync',
      );
    });
  });
}
