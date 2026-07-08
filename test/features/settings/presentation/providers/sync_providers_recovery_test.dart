import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// Coverage for the REAL SyncNotifier's issue #509 recovery methods (the
/// Troubleshoot page widget tests exercise a fake notifier, not this code):
/// Repair, the two cloud clears, and the offline-uploader rebuild.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const marker = LibraryEpochMarker(
    epochId: 'e-stuck',
    replacedAt: 1764000000000,
    deviceId: 'offline-device',
  );

  late SharedPreferences prefs;
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

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

  Uint8List b(String s) => Uint8List.fromList(s.codeUnits);

  group('repairSync', () {
    test('clears the last-accepted epoch marker', () async {
      final container = await makeContainer();
      await LibraryEpochStore(prefs).setLastAccepted(marker);

      await container.read(syncStateProvider.notifier).repairSync();

      expect(LibraryEpochStore(prefs).lastAcceptedMarker, isNull);
      expect(container.read(syncStateProvider).status, SyncStatus.idle);
    });
  });

  group('removeThisDeviceCloudFiles', () {
    test('deletes only this device’s files from the backend', () async {
      final container = await makeContainer();
      final deviceId = await container
          .read(syncRepositoryProvider)
          .getDeviceId();
      cloud.seedFile(ChangesetLogLayout.manifestName(deviceId), b('mine'));
      cloud.seedFile(
        ChangesetLogLayout.manifestName('other-device'),
        b('peer'),
      );

      await container
          .read(syncStateProvider.notifier)
          .removeThisDeviceCloudFiles();

      expect(cloud.bytesOf(ChangesetLogLayout.manifestName(deviceId)), isNull);
      expect(
        cloud.bytesOf(ChangesetLogLayout.manifestName('other-device')),
        isNotNull,
      );
    });
  });

  group('wipeAllCloudSyncData', () {
    test('deletes logs and the epoch marker', () async {
      final container = await makeContainer();
      cloud.seedFile(ChangesetLogLayout.manifestName('dev1'), b('m1'));
      seedMarker(marker);

      await container.read(syncStateProvider.notifier).wipeAllCloudSyncData();

      expect(cloud.bytesOf(ChangesetLogLayout.manifestName('dev1')), isNull);
      expect(cloud.bytesOf(libraryEpochFileName), isNull);
    });

    test('no-op when no cloud provider is configured', () async {
      final container = await makeContainer(cloudConfigured: false);
      // Must not throw with a null active provider.
      await container.read(syncStateProvider.notifier).wipeAllCloudSyncData();
    });
  });

  group('rebuildBackendFromThisDevice', () {
    test('accepts the epoch and clears awaiting-adoption', () async {
      final container = await makeContainer();
      seedMarker(marker);
      cloud.seedFile(
        ChangesetLogLayout.manifestName('offline-device'),
        b('stale'),
      );

      await container
          .read(syncStateProvider.notifier)
          .rebuildBackendFromThisDevice();

      expect(LibraryEpochStore(prefs).lastAcceptedMarker?.epochId, 'e-stuck');
      expect(
        container.read(syncStateProvider).replaceAwaitingAdoption,
        isFalse,
      );
    });

    test('surfaces an error when there is no marker to rebuild from', () async {
      final container = await makeContainer();

      await container
          .read(syncStateProvider.notifier)
          .rebuildBackendFromThisDevice();

      expect(container.read(syncStateProvider).status, SyncStatus.error);
    });
  });
}
