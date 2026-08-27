import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/wait_until.dart';

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

  tearDown(() async {
    // Close the Drift connection (not just null the reference) so open DBs
    // don't leak across tests.
    await tearDownTestDatabase();
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

      final info = await container
          .read(syncStateProvider.notifier)
          .firstSyncMergeInfo();
      expect(
        info,
        isNotNull,
        reason: 'a brand-new device must still confirm before merging',
      );
    });

    test(
      'established provider short-circuits the gate (restore case)',
      () async {
        await EstablishedProviderStore(prefs).add(cloud.providerId);
        final container = await makeContainer();
        await seedLocalDive('d1');
        await seedPeerManifest(cloud, 'peer-device');

        final info = await container
            .read(syncStateProvider.notifier)
            .firstSyncMergeInfo();
        expect(
          info,
          isNull,
          reason:
              'a device that already synced here is not first-contact, even '
              'after a restore wiped its in-DB cursor',
        );
      },
    );
  });

  test('a successful sync anchors the provider', () async {
    // No pending intent here, so _initialize stays inert and the explicit
    // performSync is the only sync (deterministic). The intent-clear behavior
    // is covered by the launch test below.
    final container = await makeContainer();
    await seedLocalDive('d1');

    await container.read(syncStateProvider.notifier).performSync();

    expect(
      EstablishedProviderStore(prefs).contains(cloud.providerId),
      isTrue,
      reason: 'a clean sync marks this provider established',
    );
  });

  group('post-restore launch sync', () {
    test(
      'a pending intent forces a sync that bypasses the first-contact gate',
      () async {
        // Arrange the EXACT condition that used to defer: peers + local dives +
        // null cursor + a pending post-restore intent.
        await PostRestoreSyncStore(prefs).setPending();
        await seedPeerManifest(cloud, 'peer-device');

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cloudStorageProviderProvider.overrideWithValue(cloud),
          ],
        );
        addTearDown(container.dispose);
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'd1'),
        );

        // Construct the notifier (runs _initialize, which forces the sync).
        container.read(syncStateProvider);
        // Wait on the concrete terminal condition (sync finished + intent
        // consumed) instead of a fixed sleep, so the test isn't CI-flaky.
        await waitUntil(() async {
          final s = container.read(syncStateProvider);
          return !s.postRestoreSyncing && !PostRestoreSyncStore(prefs).pending;
        });

        final state = container.read(syncStateProvider);
        expect(
          state.firstSyncAwaitingConfirmation,
          isFalse,
          reason: 'THE BUG: the forced post-restore sync must not defer',
        );
        expect(
          PostRestoreSyncStore(prefs).pending,
          isFalse,
          reason: 'a successful forced sync consumes the intent',
        );
        expect(
          state.postRestoreSyncing,
          isFalse,
          reason: 'the syncing flag is lowered when the forced sync finishes',
        );
      },
    );
  });

  test(
    'resetSyncState clears the anchor and the post-restore intent',
    () async {
      final container = await makeContainer();
      // Let _initialize settle; it is inert with no pending intent at
      // construction, so the stores are set here without racing a forced sync.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await EstablishedProviderStore(prefs).add(cloud.providerId);
      await PostRestoreSyncStore(prefs).setPending();

      await container.read(syncStateProvider.notifier).resetSyncState();

      expect(
        EstablishedProviderStore(prefs).contains(cloud.providerId),
        isFalse,
        reason: 'an explicit reset is a true fresh start, so re-arm the gate',
      );
      expect(PostRestoreSyncStore(prefs).pending, isFalse);
    },
  );

  test(
    'a foreign epoch with local dives arms replaceAwaitingAdoption on launch',
    () async {
      const foreign = LibraryEpochMarker(
        epochId: 'foreign-epoch',
        replacedAt: 1764000000000,
        deviceId: 'mac-device',
        deviceName: 'Eric Mac',
      );
      cloud.seedFile(
        libraryEpochFileName,
        Uint8List.fromList(utf8.encode(jsonEncode(foreign.toJson()))),
      );
      await seedLocalDive('d1');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudStorageProviderProvider.overrideWithValue(cloud),
        ],
      );
      addTearDown(container.dispose);

      // Constructing the notifier runs _initialize, which proactively detects
      // the replaced library (no pending intent, provider configured).
      container.read(syncStateProvider);
      await waitUntil(
        () async => container.read(syncStateProvider).replaceAwaitingAdoption,
      );

      final state = container.read(syncStateProvider);
      expect(
        state.replaceAwaitingAdoption,
        isTrue,
        reason: 'a replaced library must surface even with auto-sync off',
      );
      expect(state.replaceMarker?.epochId, 'foreign-epoch');
    },
  );
}
