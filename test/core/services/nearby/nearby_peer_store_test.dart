import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';

void main() {
  late AppDatabase db;
  late NearbyPeerStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    store = NearbyPeerStore(db);
  });
  tearDown(() => db.close());

  test('upsertPaired, markSynced, setError and remove round-trip', () async {
    await store.upsertPaired(
      peerDeviceId: 'p1',
      displayName: 'Laptop',
      pairedAt: 100,
    );
    var peer = await store.get('p1');
    expect(peer!.displayName, 'Laptop');
    expect(peer.pairedAt, 100);
    expect(peer.lastSyncedAt, isNull);
    expect(store.errorOf(peer), isNull);

    await store.markSynced('p1', at: 200, peerAppliedHlcHigh: 'h1');
    await store.markSeen('p1', 210);
    await store.setError('p1', NearbyPeerError.newerApp);
    peer = await store.get('p1');
    expect(peer!.lastSyncedAt, 200);
    expect(peer.lastSeenAt, 210);
    expect(peer.peerAppliedHlcHigh, 'h1');
    expect(store.errorOf(peer), NearbyPeerError.newerApp);

    // markSynced without an ack keeps the last one.
    await store.markSynced('p1', at: 300);
    peer = await store.get('p1');
    expect(peer!.peerAppliedHlcHigh, 'h1');

    await store.setError('p1', null);
    await store.rename('p1', 'Work laptop');
    peer = await store.get('p1');
    expect(store.errorOf(peer!), isNull);
    expect(peer.displayName, 'Work laptop');

    await store.remove('p1');
    expect(await store.get('p1'), isNull);
  });

  test('re-pairing keeps the row but resets its progress', () async {
    await store.upsertPaired(peerDeviceId: 'p1', displayName: 'A', pairedAt: 1);
    await store.markSynced('p1', at: 2, peerAppliedHlcHigh: 'h');
    await store.setResume('p1', baseId: 'b', partIndex: 3, offeredAt: 4);
    await store.upsertPaired(peerDeviceId: 'p1', displayName: 'B', pairedAt: 9);
    final peer = await store.get('p1');
    expect(peer!.displayName, 'B');
    expect(peer.pairedAt, 9);
    expect(peer.lastSyncedAt, isNull);
    expect(peer.peerAppliedHlcHigh, isNull);
    expect(peer.resumeBaseId, isNull);
  });

  test('setResume stores and clears the resume point', () async {
    await store.upsertPaired(peerDeviceId: 'p1', displayName: 'A', pairedAt: 1);
    await store.setResume('p1', baseId: 'base-1', partIndex: 17, offeredAt: 5);
    var peer = await store.get('p1');
    expect(peer!.resumeBaseId, 'base-1');
    expect(peer.resumePartIndex, 17);
    expect(peer.resumeOfferedAt, 5);
    await store.setResume('p1');
    peer = await store.get('p1');
    expect(peer!.resumeBaseId, isNull);
    expect(peer.resumePartIndex, isNull);
    expect(peer.resumeOfferedAt, isNull);
  });

  test('an unknown stored error reads as none', () async {
    await store.upsertPaired(peerDeviceId: 'p1', displayName: 'A', pairedAt: 1);
    await db.customStatement(
      "UPDATE nearby_peers SET last_error = 'fromTheFuture'",
    );
    expect(store.errorOf((await store.get('p1'))!), isNull);
  });

  test('watchAll emits after each change', () async {
    final emissions = <List<String>>[];
    final sub = store.watchAll().listen(
      (peers) => emissions.add([for (final p in peers) p.displayName]),
    );
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await store.upsertPaired(peerDeviceId: 'p1', displayName: 'A', pairedAt: 1);
    await pumpEventQueue();
    await store.upsertPaired(peerDeviceId: 'p2', displayName: 'B', pairedAt: 2);
    await pumpEventQueue();
    expect(emissions.first, isEmpty);
    expect(emissions.last, ['A', 'B']);
  });

  test('lasting errors are the ones that need the diver', () {
    expect(NearbyPeerError.values.where((e) => e.isLasting), [
      NearbyPeerError.newerApp,
      NearbyPeerError.peerOlderApp,
      NearbyPeerError.differentLibrary,
      NearbyPeerError.notPaired,
      NearbyPeerError.applyFailed,
    ]);
  });
}
