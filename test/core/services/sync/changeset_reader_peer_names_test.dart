import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/peer_device_name_store.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Device B learns device A's display name from A's published manifest and
/// keeps it in [PeerDeviceNameStore], so labels never need a cloud listing.
void main() {
  late AppDatabase dbA;
  late AppDatabase dbB;
  late FakeCloudStorageProvider cloud;
  late PeerDeviceNameStore names;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    names = PeerDeviceNameStore(await SharedPreferences.getInstance());
    cloud = FakeCloudStorageProvider();
    dbB = await setUpTestDatabase();
    dbA = await setUpTestDatabase();
  });

  tearDown(() async {
    names.dispose();
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
    await dbA.close();
    await dbB.close();
  });

  void switchTo(AppDatabase db) {
    DatabaseService.instance.setTestDatabase(db);
    SyncClock.instance.reset();
  }

  SyncService service() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
    peerNames: names,
  );

  Future<void> seedDiver(AppDatabase db) => db
      .into(db.divers)
      .insert(
        const DiversCompanion(
          id: Value('diver1'),
          name: Value('diver1'),
          createdAt: Value(0),
          updatedAt: Value(0),
        ),
      );

  test('a pull records the peer name published on its manifest', () async {
    switchTo(dbA);
    await seedDiver(dbA);
    await SyncRepository().markRecordPending(
      entityType: 'divers',
      recordId: 'diver1',
      localUpdatedAt: 0,
    );
    final deviceA = await SyncRepository().getDeviceId();
    expect((await service().performSync()).isSuccess, isTrue);
    await restampPeerDeviceName(cloud, deviceA, deviceName: "Eric's MacBook");

    switchTo(dbB);
    expect((await service().performSync()).isSuccess, isTrue);

    expect(names.nameFor(deviceA), "Eric's MacBook");
    final deviceB = await SyncRepository().getDeviceId();
    expect(
      names.nameFor(deviceB),
      isNull,
      reason: 'a pull excludes this device\'s own manifest',
    );
  });

  test('a peer that clears its name is forgotten on the next pull', () async {
    switchTo(dbA);
    await seedDiver(dbA);
    await SyncRepository().markRecordPending(
      entityType: 'divers',
      recordId: 'diver1',
      localUpdatedAt: 0,
    );
    final deviceA = await SyncRepository().getDeviceId();
    await service().performSync();
    await restampPeerDeviceName(cloud, deviceA, deviceName: "Eric's MacBook");

    switchTo(dbB);
    await service().performSync();
    expect(names.nameFor(deviceA), "Eric's MacBook");

    // A republishes without a name: a rename to empty, or a downgrade to a
    // version that publishes none. The stale label must not outlive it.
    await restampPeerDeviceName(cloud, deviceA, deviceName: null);
    await service().performSync();

    expect(names.nameFor(deviceA), isNull);
  });

  test('a failing name store costs the peer nothing', () async {
    // A name is optional metadata. Left unguarded, the write threw into the
    // per-peer catch, which marks the peer read-failed and drops its
    // changesets for the whole cycle.
    switchTo(dbA);
    await seedDiver(dbA);
    await SyncRepository().markRecordPending(
      entityType: 'divers',
      recordId: 'diver1',
      localUpdatedAt: 0,
    );
    final deviceA = await SyncRepository().getDeviceId();
    await service().performSync();
    await restampPeerDeviceName(cloud, deviceA, deviceName: "Eric's MacBook");

    switchTo(dbB);
    final failing = _FailingNameStore(await SharedPreferences.getInstance());
    addTearDown(failing.dispose);
    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
      peerNames: failing,
    ).performSync();

    expect(result.isSuccess, isTrue);
    final merged = await dbB
        .customSelect("SELECT id FROM divers WHERE id = 'diver1'")
        .getSingleOrNull();
    expect(
      merged?.read<String>('id'),
      'diver1',
      reason: "the peer's records must still merge",
    );
  });

  test('a manifest without a name records nothing', () async {
    switchTo(dbA);
    await seedDiver(dbA);
    await SyncRepository().markRecordPending(
      entityType: 'divers',
      recordId: 'diver1',
      localUpdatedAt: 0,
    );
    final deviceA = await SyncRepository().getDeviceId();
    await service().performSync();
    await restampPeerDeviceName(cloud, deviceA, deviceName: null);

    switchTo(dbB);
    await service().performSync();

    expect(names.nameFor(deviceA), isNull);
  });
}

/// A store whose write always fails, standing in for a preferences backend
/// that is full, locked or unavailable.
class _FailingNameStore extends PeerDeviceNameStore {
  _FailingNameStore(super.prefs);

  @override
  Future<void> record(String deviceId, String? name) async {
    throw StateError('preferences unavailable');
  }
}
