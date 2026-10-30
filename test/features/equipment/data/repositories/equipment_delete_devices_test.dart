import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// One delete for a device and its Equipment item (issue #3676): deleting the
/// item deletes the dive computer or transmitter behind it, and deleting a
/// computer takes its channel-only transmitter keys with it.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<void> item(String id, String type) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          diverId: const Value('d1'),
          name: id,
          type: type,
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<void> computer(String id, {String? equipmentId}) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion.insert(
          id: id,
          diverId: const Value('d1'),
          name: id,
          equipmentId: Value(equipmentId),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<void> transmitter(
    String id, {
    String? serial,
    String? computerId,
    int? channel,
    String? itemId,
  }) => db
      .into(db.transmitters)
      .insert(
        TransmittersCompanion.insert(
          id: id,
          diverId: const Value('d1'),
          label: id,
          tankRole: 'backGas',
          transmitterSerial: Value(serial),
          diveComputerId: Value(computerId),
          channelIndex: Value(channel),
          transmitterEquipmentId: Value(itemId),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  test('deleting a computer item deletes its registration and keeps its '
      'dives', () async {
    await item('gear', 'computer');
    await computer('c1', equipmentId: 'gear');
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive1',
            diverId: const Value('d1'),
            computerId: const Value('c1'),
            diveDateTime: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    await EquipmentRepository().deleteEquipment('gear');

    expect(await db.select(db.diveComputers).get(), isEmpty);
    final dives = await db.select(db.dives).get();
    expect(dives.single.id, 'dive1');
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.map((t) => (t.entityType, t.recordId)),
      containsAll([('diveComputers', 'c1'), ('equipment', 'gear')]),
    );
  });

  test('deleting a transmitter item deletes its rows', () async {
    await item('tx-gear', 'transmitter');
    await transmitter('tx1', serial: '4A21F', itemId: 'tx-gear');

    await EquipmentRepository().deleteEquipment('tx-gear');

    expect(await db.select(db.transmitters).get(), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.map((t) => (t.entityType, t.recordId)),
      contains(('transmitters', 'tx1')),
    );
  });

  test('deleting a computer deletes its channel-only transmitter rows and '
      'keeps their items', () async {
    await item('gear', 'computer');
    await computer('c1', equipmentId: 'gear');
    await item('tx-gear', 'transmitter');
    await transmitter('ch', computerId: 'c1', channel: 1, itemId: 'tx-gear');
    await transmitter(
      'serial',
      serial: '4A21F',
      computerId: 'c1',
      channel: 2,
      itemId: 'tx-gear',
    );

    await DiveComputerRepository().deleteComputer('c1');

    final rows = await db.select(db.transmitters).get();
    expect(rows.map((r) => r.id), ['serial']);
    expect(rows.single.diveComputerId, isNull);
    expect(rows.single.channelIndex, isNull);
    expect(
      (await db.select(db.equipment).get()).map((e) => e.id),
      containsAll(['tx-gear']),
    );
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.map((t) => (t.entityType, t.recordId)),
      contains(('transmitters', 'ch')),
    );
  });
}
