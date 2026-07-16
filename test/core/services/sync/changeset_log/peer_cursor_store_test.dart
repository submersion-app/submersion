import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';

void main() {
  late AppDatabase db;
  late PeerCursorStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = PeerCursorStore(db);
  });
  tearDown(() => db.close());

  test('get returns null for an unknown peer', () async {
    expect(await store.get('peer-x', 's3'), isNull);
  });

  test('upsert then get round-trips, and upsert overwrites', () async {
    await store.upsert(
      peerDeviceId: 'p1',
      provider: 's3',
      baseSeqApplied: 5,
      lastSeqApplied: 9,
    );
    var c = await store.get('p1', 's3');
    expect(c!.lastSeqApplied, 9);

    await store.upsert(
      peerDeviceId: 'p1',
      provider: 's3',
      baseSeqApplied: 5,
      lastSeqApplied: 14,
    );
    c = await store.get('p1', 's3');
    expect(c!.lastSeqApplied, 14);
  });

  test('cursors are isolated per provider', () async {
    await store.upsert(peerDeviceId: 'p1', provider: 's3', lastSeqApplied: 9);
    await store.upsert(
      peerDeviceId: 'p1',
      provider: 'icloud',
      lastSeqApplied: 2,
    );
    expect((await store.get('p1', 's3'))!.lastSeqApplied, 9);
    expect((await store.get('p1', 'icloud'))!.lastSeqApplied, 2);
  });

  test('resetForProvider clears only that provider', () async {
    await store.upsert(peerDeviceId: 'p1', provider: 's3', lastSeqApplied: 9);
    await store.upsert(
      peerDeviceId: 'p1',
      provider: 'icloud',
      lastSeqApplied: 2,
    );
    await store.resetForProvider('s3');
    expect(await store.get('p1', 's3'), isNull);
    expect(await store.get('p1', 'icloud'), isNotNull);
  });

  test('upsert with null appliedHlcHigh preserves the stored ack', () async {
    await store.upsert(
      peerDeviceId: 'p1',
      provider: 'fake',
      lastSeqApplied: 1,
      appliedHlcHigh: '00000000000010:000000:p1',
    );
    await store.upsert(peerDeviceId: 'p1', provider: 'fake', lastSeqApplied: 2);
    final cursor = await store.get('p1', 'fake');
    expect(cursor!.lastSeqApplied, 2);
    expect(cursor.appliedHlcHigh, '00000000000010:000000:p1');
  });
}
