import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/library_moved.dart';
import 'package:submersion/core/services/sync/library_moved_store.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// The notifier side of the backend-switch concerns: leaving a marker on the
/// old backend, surfacing it to a straggler, and offering old-data cleanup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  Future<ProviderContainer> makeContainer(
    FakeCloudStorageProvider cloud,
  ) async {
    final prefs = await SharedPreferences.getInstance();
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

  group('recordBackendDeparture', () {
    test('leaves a moved marker on the old backend and arms cleanup', () async {
      final oldBackend = FakeCloudStorageProvider(
        providerId: 's3',
        providerName: 'S3',
      );
      final container = await makeContainer(oldBackend);
      final notifier = container.read(syncStateProvider.notifier);

      await notifier.recordBackendDeparture(
        oldProvider: oldBackend,
        toProviderId: 'icloud',
        toProviderName: 'iCloud',
      );

      final marker = await container
          .read(syncServiceProvider)
          .readLibraryMovedMarker(oldBackend);
      expect(marker, isNotNull);
      expect(marker!.toProviderId, 'icloud');

      final store = LibraryMovedStore(
        container.read(sharedPreferencesProvider),
      );
      expect(
        store.pendingCleanup,
        's3',
        reason: 'the old backend must be armed for post-switch cleanup',
      );
    });

    test('stamps an unstamped cursor for the old backend so it cannot bleed '
        'into the new one', () async {
      final oldBackend = FakeCloudStorageProvider(
        providerId: 's3',
        providerName: 'S3',
      );
      // A legacy (unstamped) cursor, as an upgrader would have.
      await SyncRepository().updateLastSyncTime(DateTime(2026, 1, 1));
      final container = await makeContainer(oldBackend);

      await container
          .read(syncStateProvider.notifier)
          .recordBackendDeparture(
            oldProvider: oldBackend,
            toProviderId: 'icloud',
            toProviderName: 'iCloud',
          );

      final repo = SyncRepository();
      expect(await repo.getLastSyncTime(forProvider: 's3'), isNotNull);
      expect(
        await repo.getLastSyncTime(forProvider: 'icloud'),
        isNull,
        reason:
            'after departure the cursor belongs to s3 only; the new backend '
            'must still see first contact',
      );
    });
  });

  group('checkLibraryMoved', () {
    test('surfaces an unacknowledged marker that points elsewhere', () async {
      final cloud = FakeCloudStorageProvider(); // providerId 'fake'
      final container = await makeContainer(cloud);
      final notifier = container.read(syncStateProvider.notifier);
      // A marker left by another device that moved to iCloud.
      await container
          .read(syncServiceProvider)
          .writeLibraryMovedMarker(
            cloud,
            const LibraryMovedMarker(
              movedAt: 1,
              toProviderId: 'icloud',
              toProviderName: 'iCloud',
              deviceId: 'device-A',
            ),
          );

      await notifier.checkLibraryMoved();

      expect(container.read(syncStateProvider).movedMarker, isNotNull);
    });

    test(
      'ignores a marker that points to the backend we are already on',
      () async {
        final cloud = FakeCloudStorageProvider(); // providerId 'fake'
        final container = await makeContainer(cloud);
        await container
            .read(syncServiceProvider)
            .writeLibraryMovedMarker(
              cloud,
              const LibraryMovedMarker(
                movedAt: 1,
                toProviderId: 'fake',
                deviceId: 'device-A',
              ),
            );

        await container.read(syncStateProvider.notifier).checkLibraryMoved();

        expect(
          container.read(syncStateProvider).movedMarker,
          isNull,
          reason: 'we ARE on the destination backend; nothing has moved away',
        );
      },
    );

    test('clears an already-shown banner when a later check finds the marker '
        'now points to the backend we are on', () async {
      final cloud = FakeCloudStorageProvider(); // providerId 'fake'
      final container = await makeContainer(cloud);
      final notifier = container.read(syncStateProvider.notifier);
      final service = container.read(syncServiceProvider);

      // First, a foreign marker surfaces the banner.
      await service.writeLibraryMovedMarker(
        cloud,
        const LibraryMovedMarker(
          movedAt: 1,
          toProviderId: 'icloud',
          deviceId: 'device-A',
        ),
      );
      await notifier.checkLibraryMoved();
      expect(container.read(syncStateProvider).movedMarker, isNotNull);

      // Then the marker is rewritten to point at THIS backend (e.g. the fleet
      // converged back). The next check must clear the stale banner.
      await service.writeLibraryMovedMarker(
        cloud,
        const LibraryMovedMarker(
          movedAt: 2,
          toProviderId: 'fake',
          deviceId: 'device-A',
        ),
      );
      await notifier.checkLibraryMoved();

      expect(container.read(syncStateProvider).movedMarker, isNull);
    });

    test('does not resurface a moved marker after acknowledgement when the '
        'check runs again', () async {
      final cloud = FakeCloudStorageProvider();
      final container = await makeContainer(cloud);
      final notifier = container.read(syncStateProvider.notifier);
      await container
          .read(syncServiceProvider)
          .writeLibraryMovedMarker(
            cloud,
            const LibraryMovedMarker(
              movedAt: 7,
              toProviderId: 'icloud',
              deviceId: 'device-A',
            ),
          );
      await notifier.checkLibraryMoved();
      await notifier.acknowledgeMoved();

      await notifier.checkLibraryMoved();

      expect(container.read(syncStateProvider).movedMarker, isNull);
    });

    test(
      'acknowledge clears the banner and suppresses re-notification',
      () async {
        final cloud = FakeCloudStorageProvider();
        final container = await makeContainer(cloud);
        final notifier = container.read(syncStateProvider.notifier);
        await container
            .read(syncServiceProvider)
            .writeLibraryMovedMarker(
              cloud,
              const LibraryMovedMarker(
                movedAt: 1,
                toProviderId: 'icloud',
                deviceId: 'device-A',
              ),
            );

        await notifier.checkLibraryMoved();
        expect(container.read(syncStateProvider).movedMarker, isNotNull);

        await notifier.acknowledgeMoved();
        expect(container.read(syncStateProvider).movedMarker, isNull);

        // A second check must not bring it back.
        await notifier.checkLibraryMoved();
        expect(container.read(syncStateProvider).movedMarker, isNull);
      },
    );
  });

  group('old-backend cleanup offer', () {
    test('surfaces after a successful sync on a different backend, then '
        'cleanup clears it', () async {
      // Active backend is 'fake'; an old 's3' backend is armed for cleanup.
      final cloud = FakeCloudStorageProvider();
      final container = await makeContainer(cloud);
      final notifier = container.read(syncStateProvider.notifier);
      await LibraryMovedStore(
        container.read(sharedPreferencesProvider),
      ).setPendingCleanup('s3');

      await notifier.performSync();

      expect(
        container.read(syncStateProvider).cleanupOldBackendProviderId,
        's3',
        reason:
            'the first successful sync on the new backend is the safe moment '
            'to offer deleting the old copy',
      );

      await notifier.dismissOldBackendCleanup();
      expect(
        container.read(syncStateProvider).cleanupOldBackendProviderId,
        isNull,
      );
      expect(
        LibraryMovedStore(
          container.read(sharedPreferencesProvider),
        ).pendingCleanup,
        isNull,
        reason: 'dismissing the offer must disarm it so it stops reappearing',
      );
    });

    test('cleanupOldBackendData runs the cleanup and disarms it', () async {
      // Active backend 'fake'; arm an 's3' backend for cleanup, then surface
      // and accept the offer. The old-backend cleanup resolves the real S3
      // singleton (unconfigured -> fails fast and is swallowed), so this
      // exercises the resolve + best-effort cleanup + disarm path.
      final cloud = FakeCloudStorageProvider();
      final container = await makeContainer(cloud);
      final notifier = container.read(syncStateProvider.notifier);
      final store = LibraryMovedStore(
        container.read(sharedPreferencesProvider),
      );
      await store.setPendingCleanup('s3');
      await notifier.performSync();
      expect(
        container.read(syncStateProvider).cleanupOldBackendProviderId,
        's3',
      );

      await notifier.cleanupOldBackendData();

      expect(
        container.read(syncStateProvider).cleanupOldBackendProviderId,
        isNull,
      );
      expect(store.pendingCleanup, isNull);
    });

    test('no offer when the active backend IS the armed one (no real switch '
        'happened yet)', () async {
      final cloud = FakeCloudStorageProvider(); // providerId 'fake'
      final container = await makeContainer(cloud);
      await LibraryMovedStore(
        container.read(sharedPreferencesProvider),
      ).setPendingCleanup('fake');

      await container.read(syncStateProvider.notifier).performSync();

      expect(
        container.read(syncStateProvider).cleanupOldBackendProviderId,
        isNull,
        reason:
            'syncing against the same backend that is armed means the switch '
            'has not actually moved data to a new one yet',
      );
    });
  });

  group('signOut', () {
    test('a Dropbox sign-out clears the selection even when the legacy '
        'keychain-clear fails (best-effort)', () async {
      final backend = FakeCloudStorageProvider(
        providerId: 'dropbox',
        providerName: 'Dropbox',
      );
      final container = await makeContainer(backend);
      container.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.dropbox;
      final notifier = container.read(syncStateProvider.notifier);

      // DropboxAuthStore().clear() hits real secure storage, which throws
      // under flutter_test; sign-out must swallow that and still complete.
      await notifier.signOut();

      expect(
        container.read(selectedCloudProviderTypeProvider),
        isNull,
        reason:
            'a keychain-clear failure must not abort sign-out: the provider '
            'selection (and derived state) still has to be cleared',
      );
    });
  });
}
