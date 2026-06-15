import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Bytes for a throwaway sync payload file. Content is irrelevant to the launch
/// check -- only the file's name and mtime matter.
final _payload = Uint8List.fromList([1, 2, 3]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncRepository repository;
  late SyncInitializer initializer;
  late FakeCloudStorageProvider provider;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = SyncRepository();
    // Materialize the sync-metadata row up front. updateLastSyncTime() issues a
    // bare UPDATE and is a no-op until getOrCreateMetadata() has created it.
    await repository.getDeviceId();
    initializer = SyncInitializer(syncRepository: repository, prefs: prefs);
    provider = FakeCloudStorageProvider();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // A peer is discovered by its changeset-log manifest, one per device.
  String peerFileName(String deviceId) =>
      ChangesetLogLayout.manifestName(deviceId);

  group('checkSyncOnLaunch preconditions', () {
    test('returns notConfigured when no provider is given', () async {
      final result = await initializer.checkSyncOnLaunch(null);
      expect(result.status, SyncCheckStatus.notConfigured);
    });

    test('returns unavailable when the provider is not available', () async {
      provider.available = false;
      final result = await initializer.checkSyncOnLaunch(provider);
      expect(result.status, SyncCheckStatus.unavailable);
    });

    test('returns notAuthenticated when not signed in', () async {
      provider.authenticated = false;
      final result = await initializer.checkSyncOnLaunch(provider);
      expect(result.status, SyncCheckStatus.notAuthenticated);
    });
  });

  group('checkSyncOnLaunch with no peer files', () {
    test(
      'returns noRemoteData when cloud is empty and nothing pending',
      () async {
        final result = await initializer.checkSyncOnLaunch(provider);
        expect(result.status, SyncCheckStatus.noRemoteData);
      },
    );

    test(
      'returns localChanges when cloud is empty but edits are pending',
      () async {
        await repository.markRecordPending(
          entityType: 'dives',
          recordId: 'dive-1',
          localUpdatedAt: DateTime(2026).millisecondsSinceEpoch,
        );

        final result = await initializer.checkSyncOnLaunch(provider);

        expect(result.status, SyncCheckStatus.localChanges);
        expect(result.pendingChanges, 1);
      },
    );

    test('excludes our OWN per-device file from the peer set', () async {
      // Regression: persisting/inspecting our own file made the launch check
      // compare our own upload time and never see peers. Our own file must not
      // count as remote data.
      final ownId = await repository.getDeviceId();
      await provider.uploadFile(_payload, peerFileName(ownId));

      final result = await initializer.checkSyncOnLaunch(provider);

      expect(result.status, SyncCheckStatus.noRemoteData);
    });

    test('excludes iCloud "conflicted copy" duplicates', () async {
      // A conflicted copy of a manifest does not end in the canonical
      // `.manifest.json`, so peer discovery skips it.
      await provider.uploadFile(
        _payload,
        'ssv1.deviceB.manifest (conflicted copy 2026).json',
      );

      final result = await initializer.checkSyncOnLaunch(provider);

      expect(result.status, SyncCheckStatus.noRemoteData);
    });
  });

  group('checkSyncOnLaunch with peer files', () {
    test('updatesAvailable when a peer file is newer than last sync', () async {
      await provider.uploadFile(_payload, peerFileName('deviceB'));
      // Peer mtime is ~now; a 2020 last-sync is clearly older.
      await repository.updateLastSyncTime(DateTime(2020));

      final result = await initializer.checkSyncOnLaunch(provider);

      expect(result.status, SyncCheckStatus.updatesAvailable);
      expect(result.remoteModified, isNotNull);
    });

    test(
      'updatesAvailable when there is a peer file but no local last sync',
      () async {
        await provider.uploadFile(_payload, peerFileName('deviceB'));

        final result = await initializer.checkSyncOnLaunch(provider);

        expect(result.status, SyncCheckStatus.updatesAvailable);
      },
    );

    test('upToDate when the newest peer file predates last sync', () async {
      await provider.uploadFile(_payload, peerFileName('deviceB'));
      // Peer mtime is ~now; a far-future last-sync is clearly newer.
      await repository.updateLastSyncTime(DateTime(2999));

      final result = await initializer.checkSyncOnLaunch(provider);

      expect(result.status, SyncCheckStatus.upToDate);
    });

    test('localChanges when peer is not newer but edits are pending', () async {
      await provider.uploadFile(_payload, peerFileName('deviceB'));
      await repository.updateLastSyncTime(DateTime(2999));
      await repository.markRecordPending(
        entityType: 'dives',
        recordId: 'dive-1',
        localUpdatedAt: DateTime(2026).millisecondsSinceEpoch,
      );

      final result = await initializer.checkSyncOnLaunch(provider);

      expect(result.status, SyncCheckStatus.localChanges);
      expect(result.pendingChanges, 1);
    });

    test('our own file alongside a peer still detects the peer', () async {
      final ownId = await repository.getDeviceId();
      await provider.uploadFile(_payload, peerFileName(ownId));
      await provider.uploadFile(_payload, peerFileName('deviceB'));
      await repository.updateLastSyncTime(DateTime(2020));

      final result = await initializer.checkSyncOnLaunch(provider);

      expect(result.status, SyncCheckStatus.updatesAvailable);
    });
  });

  group('checkSyncOnLaunch provider persistence', () {
    test('saveProvider then getLastProvider round-trips', () async {
      expect(initializer.getLastProvider(), isNull);
      await initializer.saveProvider(CloudProviderType.icloud);
      expect(initializer.getLastProvider(), CloudProviderType.icloud);
      await initializer.saveProvider(null);
      expect(initializer.getLastProvider(), isNull);
    });
  });
}
