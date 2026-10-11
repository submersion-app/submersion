import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Dive computer connections (v279, issue #3106) in sync: a top-level
/// last-writer-wins entity whose `address` and `localLastUsedAt` belong to
/// the device that made the connection and never travel.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'dc',
            name: 'Perdix 2',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<void> insertLocal({String address = 'AA:BB', int local = 9}) async {
    await db
        .into(db.diveComputerConnections)
        .insert(
          DiveComputerConnectionsCompanion.insert(
            id: 'conn',
            computerId: 'dc',
            kind: 'ble',
            firstUsedAt: 3,
            lastUsedAt: 4,
            address: Value(address),
            localLastUsedAt: Value(local),
            createdAt: 3,
            updatedAt: 4,
          ),
        );
  }

  Map<String, dynamic> peerRow({int lastUsedAt = 50}) => {
    'id': 'conn',
    'computerId': 'dc',
    'kind': 'ble',
    'detail': null,
    'firstUsedAt': 3,
    'lastUsedAt': lastUsedAt,
    'address': 'PEER-ADDRESS',
    'localLastUsedAt': 77,
    'createdAt': 3,
    'updatedAt': lastUsedAt,
    'hlc': null,
  };

  test('fetchRecord carries no device-local columns', () async {
    await insertLocal();
    final row = await serializer.fetchRecord('diveComputerConnections', 'conn');
    expect(row?['kind'], 'ble');
    expect(row?['lastUsedAt'], 4);
    expect(row, isNot(contains('address')));
    expect(row, isNot(contains('localLastUsedAt')));
  });

  test('a full export carries the row without device-local columns', () async {
    await insertLocal();
    final payload = await serializer.exportData(
      deviceId: 'dev',
      deletions: const [],
    );
    final row = payload.data.diveComputerConnections.single;
    expect(row['id'], 'conn');
    expect(row, isNot(contains('address')));
    expect(row, isNot(contains('localLastUsedAt')));
  });

  test('a changeset carries a pending row without device-local '
      'columns', () async {
    await insertLocal();
    await SyncRepository().markRecordPending(
      entityType: 'diveComputerConnections',
      recordId: 'conn',
      localUpdatedAt: 5,
    );
    final payload = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: '0000000000000:0000:0000',
      deletions: const [],
    );
    final row = payload.data.diveComputerConnections.single;
    expect(row['id'], 'conn');
    expect(row, isNot(contains('address')));
    expect(row, isNot(contains('localLastUsedAt')));
  });

  test('applying a peer row keeps this device\'s address and last use, and '
      'takes the peer\'s library-wide last use', () async {
    await insertLocal();
    await serializer.upsertRecord('diveComputerConnections', peerRow());
    final row = await (db.select(
      db.diveComputerConnections,
    )..where((t) => t.id.equals('conn'))).getSingle();
    expect(row.address, 'AA:BB');
    expect(row.localLastUsedAt, 9);
    expect(row.lastUsedAt, 50);
  });

  test('a peer row new to this device lands with no address', () async {
    await serializer.upsertRecords('diveComputerConnections', [peerRow()]);
    final row = await (db.select(
      db.diveComputerConnections,
    )..where((t) => t.id.equals('conn'))).getSingle();
    expect(row.address, isNull);
    expect(row.localLastUsedAt, isNull);
  });

  test('a peer tombstone deletes the row', () async {
    await insertLocal();
    await serializer.deleteRecord('diveComputerConnections', 'conn');
    final rows = await db.select(db.diveComputerConnections).get();
    expect(rows, isEmpty);
  });
}
