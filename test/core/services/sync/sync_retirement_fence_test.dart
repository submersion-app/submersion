import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../../../support/fake_cloud_storage_provider.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  Future<bool> hasDive(String id) async =>
      (await DatabaseService.instance.database
          .customSelect("SELECT id FROM dives WHERE id = '$id'")
          .getSingleOrNull()) !=
      null;

  test('retired device rejoins: cloud wins, pending records survive', () async {
    final cloud = FakeCloudStorageProvider();
    final folder = await cloud.getOrCreateSyncFolder();

    // The current cloud library: peer-1 holds ONLY 'keep-1'. ('stale-1' was
    // deleted fleet-wide long ago; its tombstone is GC'd -- absent here.)
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'keep-1', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-1'); // resets the local DB afterwards

    // The returning device's local state, built AFTER the reset:
    // - 'stale-1': previously synced (published), deleted elsewhere since.
    // - 'mine-offline': created while offline, never published (pending).
    final svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'stale-1', diveNumber: 2),
    );
    expect((await svc.performSync()).status, SyncResultStatus.success);
    // Now go "offline": log a dive that never syncs before the retirement.
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'mine-offline', diveNumber: 3),
    );

    // The fleet retires this device while it is away. (deleteDeviceSyncFile
    // wipes every file carrying the device id including markers, so the
    // marker is written after it here; production's sweep skips markers.)
    final deviceId = await SyncRepository().getDeviceId();
    await svc.deleteDeviceSyncFile(deviceId);
    await cloud.uploadFile(
      RetirementMarker(
        deviceId: deviceId,
        retiredAt: DateTime.now().millisecondsSinceEpoch,
      ).toBytes(),
      ChangesetLogLayout.retiredMarkerName(deviceId),
      folderId: folder,
    );

    // The device comes back and syncs: the fence rebuilds from the cloud.
    final result = await svc.performSync();
    expect(result.status, SyncResultStatus.success);

    expect(await hasDive('keep-1'), isTrue, reason: 'cloud library adopted');
    expect(
      await hasDive('stale-1'),
      isFalse,
      reason: 'deleted-elsewhere record removed (silent cloud-wins)',
    );
    expect(
      await hasDive('mine-offline'),
      isTrue,
      reason: 'offline-created pending record must survive the fence',
    );

    // The marker is gone and the device published again (live once more).
    final names = (await cloud.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    )).map((f) => f.name).toList();
    expect(
      names,
      isNot(contains(ChangesetLogLayout.retiredMarkerName(deviceId))),
    );
    expect(
      names.where((n) => ChangesetLogLayout.deviceIdOf(n) == deviceId),
      isNotEmpty,
      reason: 'the rejoined device must publish its pending records',
    );

    // And the pending record actually reaches the cloud: a fresh device
    // adopting now must see mine-offline but not stale-1.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final svc2 = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    expect((await svc2.performSync()).status, SyncResultStatus.success);
    expect(await hasDive('mine-offline'), isTrue);
    expect(await hasDive('stale-1'), isFalse);
  });

  test(
    'fence with no readable cloud library re-establishes from local',
    () async {
      final cloud = FakeCloudStorageProvider();
      final folder = await cloud.getOrCreateSyncFolder();
      final svc = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      );
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      expect((await svc.performSync()).status, SyncResultStatus.success);
      final deviceId = await SyncRepository().getDeviceId();
      // Retired (marker present, own files gone) but NO peer library exists.
      await svc.deleteDeviceSyncFile(deviceId);
      await cloud.uploadFile(
        RetirementMarker(deviceId: deviceId, retiredAt: 1).toBytes(),
        ChangesetLogLayout.retiredMarkerName(deviceId),
        folderId: folder,
      );

      final result = await svc.performSync();
      expect(result.status, SyncResultStatus.success);
      expect(
        await hasDive('d1'),
        isTrue,
        reason: 'local data must never be wiped',
      );
      final names = (await cloud.listFiles(
        folderId: folder,
        namePattern: ChangesetLogLayout.prefix,
      )).map((f) => f.name).toList();
      expect(
        names,
        isNot(contains(ChangesetLogLayout.retiredMarkerName(deviceId))),
      );
      expect(
        names.where((n) => ChangesetLogLayout.deviceIdOf(n) == deviceId),
        isNotEmpty,
        reason: 'device republishes its library',
      );
    },
  );
}
