import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/core/services/nearby/nearby_sync_engine.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SyncRepository repo;
  late SyncDataSerializer serializer;
  late NearbyPeerStore peers;
  late LibraryEpochStore epochs;
  late DatabaseNearbySyncEngine engine;

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    repo = SyncRepository();
    serializer = SyncDataSerializer();
    peers = NearbyPeerStore(db);
    epochs = LibraryEpochStore(await SharedPreferences.getInstance());
    engine = DatabaseNearbySyncEngine(
      syncService: () =>
          SyncService(syncRepository: repo, serializer: serializer),
      serializer: serializer,
      syncRepository: repo,
      peerCursors: PeerCursorStore(db),
      publishStates: PublishStateStore(db),
      peers: peers,
      epochStore: epochs,
      database: db,
      resolveIdentity: () async =>
          (id: await repo.getDeviceId(), name: 'Phone', appVersion: '1.8.4'),
    );
  });
  tearDown(() async {
    SyncCoordinator.reset();
    await tearDownTestDatabase();
  });

  /// A one-dive payload, as a peer would send it, then the dive removed
  /// locally without a tombstone so applying it has something to do.
  Future<SyncPayload> peerPayloadWithOneDive() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final payload = await serializer.exportChangeset(
      deviceId: 'peer',
      hlcWatermark: null,
      deletions: const [],
    );
    await db.customStatement("DELETE FROM dives WHERE id = 'd1'");
    // The local create marked d1 pending; a pending row is a local edit in
    // flight, which the merge must not overwrite.
    await repo.clearAllSyncRecords();
    return payload;
  }

  test('identity carries the device, schema, floor, epoch and dives', () async {
    var id = await engine.identity();
    expect(id.deviceId, await repo.getDeviceId());
    expect(id.deviceName, 'Phone');
    expect(id.schemaVersion, AppDatabase.currentSchemaVersion);
    expect(id.schemaFloor, AppDatabase.minimumCompatibleSchemaVersion);
    expect(id.epochId, isNull);
    expect(id.hasDives, isFalse);

    await engine.adoptEpoch('epoch-x');
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd9', diveNumber: 9),
    );
    id = await engine.identity();
    expect(id.epochId, 'epoch-x');
    expect(id.hasDives, isTrue);
  });

  test(
    'adoptEpoch stores the marker in the prefs store and the repository',
    () async {
      await engine.adoptEpoch('epoch-y');
      expect(epochs.lastAcceptedEpochId, 'epoch-y');
      expect(epochs.lastAcceptedMarker!.deviceId, await repo.getDeviceId());
      expect(await repo.getLastAcceptedEpochId(), 'epoch-y');
    },
  );

  test('applyPayload merges a dive and reports recordsApplied', () async {
    final payload = await peerPayloadWithOneDive();
    await peers.upsertPaired(
      peerDeviceId: 'peer',
      displayName: 'Laptop',
      pairedAt: 1,
    );
    final r = await engine.applyPayload(payload, peerDeviceId: 'peer');
    expect(r.recordsApplied, greaterThanOrEqualTo(1));
    final rows = await db
        .customSelect("SELECT id FROM dives WHERE id = 'd1'")
        .get();
    expect(rows, hasLength(1));
  });

  test('applyPayload waits for a running SyncCoordinator body', () async {
    final payload = await peerPayloadWithOneDive();
    final gate = Completer<void>();
    final running = SyncCoordinator.run(() => gate.future);
    var applied = false;
    final apply = engine
        .applyPayload(payload, peerDeviceId: 'peer')
        .then((_) => applied = true);
    await pumpEventQueue();
    expect(applied, isFalse);
    gate.complete();
    await running;
    await apply;
    expect(applied, isTrue);
  });

  test('recordApplied writes the nearby cursor, marks synced and pulls the '
      'cloud watermark back', () async {
    await peers.upsertPaired(
      peerDeviceId: 'peer',
      displayName: 'Laptop',
      pairedAt: 1,
    );
    await PublishStateStore(db).upsert(
      const LocalPublishStatesCompanion(
        provider: Value('icloud'),
        headSeq: Value(3),
        publishedHlcHigh: Value('000000000000900:000000:me'),
        updatedAt: Value(1),
      ),
    );
    await engine.recordApplied(
      peerDeviceId: 'peer',
      appliedHlcHigh: '000000000000800:000000:peer',
      lowestAppliedHlc: '000000000000500:000002:peer',
    );
    final cursor = await PeerCursorStore(db).get('peer', 'nearby');
    expect(cursor!.appliedHlcHigh, '000000000000800:000000:peer');
    expect(cursor.lastSeqApplied, 0);
    expect(
      (await PublishStateStore(db).get('icloud'))!.relayFloorHlc,
      '000000000000500:000002:',
    );
    // The session's lastSync stays put until the whole session ends: the
    // manager stamps it then, so both directions merge against one value.
    expect((await peers.get('peer'))!.lastSyncedAt, isNull);
  });

  test(
    'recordApplied for a peer unpaired meanwhile writes no cursor',
    () async {
      await engine.recordApplied(
        peerDeviceId: 'gone',
        appliedHlcHigh: '000000000000800:000000:gone',
        lowestAppliedHlc: null,
      );
      expect(await PeerCursorStore(db).get('gone', 'nearby'), isNull);
    },
  );

  test('lowestClockOf finds the oldest clock a writer has here', () async {
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, hlc) VALUES '
      "('t1', 'A', 0, 0, '000000000000300:000000:w1'), "
      "('t2', 'B', 0, 0, '000000000000100:000000:w1'), "
      "('t3', 'C', 0, 0, '000000000000050:000000:w2')",
    );
    expect(await engine.lowestClockOf('w1'), '000000000000100:000000:w1');
    expect(await engine.lowestClockOf('nobody'), isNull);
  });

  test('recordPeerAck stores what the peer has of mine', () async {
    await peers.upsertPaired(
      peerDeviceId: 'peer',
      displayName: 'Laptop',
      pairedAt: 1,
    );
    await engine.recordPeerAck(
      peerDeviceId: 'peer',
      peerAppliedHlcHigh: '000000000000700:000000:me',
    );
    expect(
      (await peers.get('peer'))!.peerAppliedHlcHigh,
      '000000000000700:000000:me',
    );
    expect((await peers.get('peer'))!.lastSyncedAt, isNull);
  });

  test('exportDelta carries rows above the watermark and the epoch', () async {
    await engine.adoptEpoch('epoch-z');
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final first = await serializer.fetchRecord('dives', 'd1');
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    final delta = await engine.exportDelta(first!['hlc'] as String);
    expect(delta.data.dives.map((d) => d['id']), ['d2']);
    expect(delta.epochId, 'epoch-z');
    expect(serializer.validateChecksum(delta), isTrue);
  });

  test('exportFull streams every row to a temp file', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final base = await engine.exportFull();
    expect(base.rowCount, greaterThan(0));
    expect(base.byteLength, greaterThan(0));
  });
}
