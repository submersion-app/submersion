import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Replacing the cloud library from this device: the preflight that describes
/// the blast radius, and the intent that arms the replacement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Future<ProviderContainer> makeContainer({bool withProvider = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(
          withProvider ? FakeCloudStorageProvider() : null,
        ),
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

  group('replacePreflight', () {
    test('reports local dives and the peer count', () async {
      final container = await makeContainer();
      final cloud =
          container.read(cloudStorageProviderProvider)
              as FakeCloudStorageProvider;
      await seedLocalDive('local-1');
      await seedLocalDive('local-2');
      await seedPeerManifest(cloud, 'peer-device');

      final preflight = await container
          .read(syncStateProvider.notifier)
          .replacePreflight();

      expect(preflight.localDiveCount, 2);
      expect(preflight.peerFileCount, 1);
      expect(preflight.hasPeerCount, isTrue);
    });

    test('a solo device reports zero peers, not an unknown count', () async {
      final container = await makeContainer();
      await seedLocalDive('local-1');

      final preflight = await container
          .read(syncStateProvider.notifier)
          .replacePreflight();

      expect(preflight.peerFileCount, 0);
      expect(
        preflight.hasPeerCount,
        isTrue,
        reason: 'zero peers is an answer; only a failed listing is unknown',
      );
    });

    test(
      'with no provider the peer count is unknown, and it does not throw',
      () async {
        final container = await makeContainer(withProvider: false);
        await seedLocalDive('local-1');

        final preflight = await container
            .read(syncStateProvider.notifier)
            .replacePreflight();

        expect(preflight.localDiveCount, 1);
        expect(preflight.peerFileCount, isNull);
        expect(preflight.hasPeerCount, isFalse);
      },
    );
  });

  group('replaceCloudLibraryFromThisDevice', () {
    test('arms the replace intent', () async {
      final container = await makeContainer();
      await seedLocalDive('local-1');

      await container
          .read(syncStateProvider.notifier)
          .replaceCloudLibraryFromThisDevice();

      // The gate consumes the intent on the sync this triggers, so assert on
      // the durable outcome instead: the epoch was accepted locally.
      final store = container.read(libraryEpochStoreProvider);
      expect(
        store.pendingReplace ?? store.lastAcceptedMarker,
        isNotNull,
        reason: 'a replace must leave either a pending intent or an epoch',
      );
    });

    test(
      'drives an already-armed intent instead of minting a new one',
      () async {
        final container = await makeContainer();
        await seedLocalDive('local-1');
        final store = container.read(libraryEpochStoreProvider);

        // Arm an intent by hand, exactly as an attempt that failed mid-flight
        // would leave behind. executeLibraryReplace deliberately keeps the
        // intent on failure so the next sync retries rather than merging.
        await store.setPendingReplace(
          const LibraryEpochMarker(
            epochId: 'armed-epoch',
            replacedAt: 1,
            deviceId: 'device-1',
          ),
        );

        await container
            .read(syncStateProvider.notifier)
            .replaceCloudLibraryFromThisDevice();

        // The armed epoch is the one that landed: a re-run must finish the
        // replacement in flight, not start a second one under a new epoch.
        expect(store.lastAcceptedMarker?.epochId, 'armed-epoch');
      },
    );

    test('without a provider it errors and mints nothing', () async {
      final container = await makeContainer(withProvider: false);
      await seedLocalDive('local-1');

      await container
          .read(syncStateProvider.notifier)
          .replaceCloudLibraryFromThisDevice();

      expect(container.read(syncStateProvider).status, SyncStatus.error);
      final store = container.read(libraryEpochStoreProvider);
      expect(store.pendingReplace, isNull);
      expect(store.lastAcceptedMarker, isNull);
    });
  });
}
