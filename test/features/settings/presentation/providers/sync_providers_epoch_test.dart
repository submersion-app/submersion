import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show SyncRepository;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Coverage for the REAL SyncNotifier's library-epoch paths (the cloud sync
/// page widget tests exercise a fake notifier, not this code): replace-info
/// pre-check, adoption orchestration, awaiting-adoption state mapping, the
/// silent empty-library adopt, the pending-replace launch trigger, and the
/// Reset Sync State escape hatch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const marker = LibraryEpochMarker(
    epochId: 'e1',
    replacedAt: 1764000000000,
    deviceId: 'replacer-device',
    deviceName: 'Eric Mac',
  );

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

  Future<ProviderContainer> makeContainer({bool cloudConfigured = true}) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(
          cloudConfigured ? cloud : null,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(syncStateProvider);
    await container.read(syncStateProvider.notifier).refreshState();
    return container;
  }

  void seedMarker(LibraryEpochMarker m) {
    cloud.seedFile(
      libraryEpochFileName,
      Uint8List.fromList(utf8.encode(jsonEncode(m.toJson()))),
    );
  }

  Future<void> seedLocalDive(String id) async {
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: id));
  }

  group('libraryReplaceInfo', () {
    test('null when no cloud provider is configured', () async {
      final container = await makeContainer(cloudConfigured: false);
      final info = await container
          .read(syncStateProvider.notifier)
          .libraryReplaceInfo();
      expect(info, isNull);
    });

    test('null when this device holds the pending replace intent', () async {
      final container = await makeContainer();
      await LibraryEpochStore(prefs).setPendingReplace(marker);
      seedMarker(marker);

      final info = await container
          .read(syncStateProvider.notifier)
          .libraryReplaceInfo();
      expect(info, isNull, reason: 'the replacer must not prompt itself');
    });

    test('null when no marker exists', () async {
      final container = await makeContainer();
      final info = await container
          .read(syncStateProvider.notifier)
          .libraryReplaceInfo();
      expect(info, isNull);
    });

    test('null when the marker matches the accepted epoch', () async {
      final container = await makeContainer();
      seedMarker(marker);
      await SyncRepository().setLastAcceptedEpochId('e1');

      final info = await container
          .read(syncStateProvider.notifier)
          .libraryReplaceInfo();
      expect(info, isNull);
    });

    test('returns the marker on an unaccepted epoch', () async {
      final container = await makeContainer();
      seedMarker(marker);

      final info = await container
          .read(syncStateProvider.notifier)
          .libraryReplaceInfo();
      expect(info?.epochId, 'e1');
      expect(info?.displayName, 'Eric Mac');
    });

    test('null (never throws) when the marker is unreadable', () async {
      final container = await makeContainer();
      cloud.seedFile(
        libraryEpochFileName,
        Uint8List.fromList(utf8.encode('not json')),
      );

      final info = await container
          .read(syncStateProvider.notifier)
          .libraryReplaceInfo();
      expect(info, isNull);
    });
  });

  group('performSync awaiting-adoption mapping', () {
    test('pauses with banner state when the device holds dives', () async {
      final container = await makeContainer();
      await seedLocalDive('mine-1');
      seedMarker(marker);
      // A genuine replace also published an e1 library, so the epoch is
      // adoptable (an orphaned marker would instead auto-recover).
      await seedPeerManifest(cloud, 'replacer-device', epochId: 'e1');
      cloud.operationLog.clear();

      await container.read(syncStateProvider.notifier).performSync();

      final state = container.read(syncStateProvider);
      expect(state.replaceAwaitingAdoption, isTrue);
      expect(state.replaceMarker?.epochId, 'e1');
      expect(state.status, SyncStatus.idle);
      // Nothing was uploaded while paused.
      expect(
        cloud.operationLog.where((op) => op.startsWith('upload:')),
        isEmpty,
      );
    });

    test('adopts silently when the local library is empty', () async {
      // The replacer's restored library (one dive), stamped e1. seedPeerLog
      // resets the local DB to empty -- exactly the silent-adopt precondition.
      await seedLocalDive('restored-dive');
      await seedPeerLog(cloud, 'replacer-device', epochId: 'e1');
      seedMarker(marker);
      final container = await makeContainer();

      await container.read(syncStateProvider.notifier).performSync();

      final state = container.read(syncStateProvider);
      expect(state.replaceAwaitingAdoption, isFalse);
      expect(await SyncRepository().getLastAcceptedEpochId(), 'e1');
      // We adopted exactly the replacer's library and have no local changes of
      // our own, so the follow-up sync DEFERS our redundant self-base publish
      // (#358): the replacer already holds this library. A later local edit
      // re-enables the publish.
      final deviceId = await SyncRepository().getDeviceId();
      expect(await hasPublishedLog(cloud, deviceId), isFalse);
    });
  });

  group('adoptReplacedLibrary', () {
    test(
      'adopts the restored library, clears the pause, and re-syncs',
      () async {
        // The replacer's restored library holds dive-a; seedPeerLog resets the
        // DB, after which we diverge locally with dive-b.
        await seedLocalDive('dive-a');
        await seedPeerLog(cloud, 'replacer-device', epochId: 'e1');
        await seedLocalDive('dive-b');
        seedMarker(marker);

        final serializer = SyncDataSerializer();
        final container = await makeContainer();
        final notifier = container.read(syncStateProvider.notifier);

        // Land in the paused state first, as the UI flow would.
        await notifier.performSync();
        expect(container.read(syncStateProvider).replaceAwaitingAdoption, true);

        await notifier.adoptReplacedLibrary();

        final state = container.read(syncStateProvider);
        expect(state.replaceAwaitingAdoption, isFalse);
        expect(state.replaceMarker, isNull);
        expect(await serializer.fetchRecord('dives', 'dive-a'), isNotNull);
        expect(await serializer.fetchRecord('dives', 'dive-b'), isNull);
        expect(await SyncRepository().getLastAcceptedEpochId(), 'e1');
        // dive-b (the local divergence) was discarded by the Replace-adopt, so
        // we hold exactly the adopted library and have nothing of our own to
        // contribute -- the follow-up sync DEFERS our redundant self-base
        // publish (#358), leaving no base of ours in the cloud.
        final deviceId = await SyncRepository().getDeviceId();
        expect(await cloudBasePayload(cloud, deviceId), isNull);
      },
    );

    test('surfaces an error when a replace is still uploading', () async {
      // FRESH marker, no stamped base yet: a replace in flight (an old/orphaned
      // marker would instead auto-recover from the local library).
      seedMarker(
        LibraryEpochMarker(
          epochId: 'e1',
          replacedAt: DateTime.now().millisecondsSinceEpoch,
          deviceId: 'replacer-device',
        ),
      );
      final container = await makeContainer();
      final notifier = container.read(syncStateProvider.notifier);

      await notifier.adoptReplacedLibrary();

      final state = container.read(syncStateProvider);
      expect(state.status, SyncStatus.error);
      expect(await SyncRepository().getLastAcceptedEpochId(), isNull);
    });
  });

  group('pending replace launch trigger', () {
    test('executes a persisted replace intent on notifier startup', () async {
      await LibraryEpochStore(prefs).setPendingReplace(marker);
      await seedLocalDive('restored-dive');

      await makeContainer(); // constructing the notifier fires the trigger

      final store = LibraryEpochStore(prefs);
      for (var i = 0; i < 100 && store.pendingReplace != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(store.pendingReplace, isNull);
      expect(await SyncRepository().getLastAcceptedEpochId(), 'e1');
      expect(
        (await cloud.listFiles(namePattern: libraryEpochFileName)),
        isNotEmpty,
        reason: 'the replace wrote the marker',
      );
    });

    test('stays dormant when no cloud provider is configured', () async {
      // A persisted Replace intent must not fire performSync() without a
      // provider, or launch would surface a "no provider configured" error
      // even for users who never enabled cloud sync.
      await LibraryEpochStore(prefs).setPendingReplace(marker);
      await seedLocalDive('restored-dive');

      final container = await makeContainer(cloudConfigured: false);

      // Let _initialize run its async chain (restore + refresh + intent check).
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      // The intent survives for a later launch that has a provider...
      expect(LibraryEpochStore(prefs).pendingReplace, isNotNull);
      // ...and launch never drove the notifier into an error/syncing state.
      expect(container.read(syncStateProvider).status, SyncStatus.idle);
    });
  });

  group('resetSyncState escape hatch', () {
    test('clears a stuck pending replace intent', () async {
      final container = await makeContainer();
      await LibraryEpochStore(prefs).setPendingReplace(marker);

      await container.read(syncStateProvider.notifier).resetSyncState();

      expect(LibraryEpochStore(prefs).pendingReplace, isNull);
      final state = container.read(syncStateProvider);
      expect(state.replaceAwaitingAdoption, isFalse);
    });
  });
}
