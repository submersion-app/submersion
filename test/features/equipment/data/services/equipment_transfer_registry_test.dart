import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';

import '../../../../helpers/test_database.dart';

/// Dive computers and transmitters linked to transferred gear, and the
/// dialog's preview (issue #2852).
void main() {
  late AppDatabase db;
  late EquipmentTransferService service;

  Future<void> addDiver(String id) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
        );
  }

  Future<void> addItem(String id, String owner, {String? host}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'other',
            createdAt: t,
            updatedAt: t,
            diverId: Value(owner),
            parentEquipmentId: Value(host),
          ),
        );
  }

  Future<void> addComputer(String id, String owner, {String? gear}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: id,
            createdAt: t,
            updatedAt: t,
            diverId: Value(owner),
            equipmentId: Value(gear),
          ),
        );
  }

  Future<void> addTransmitter(
    String id,
    String owner, {
    String? serial,
    String? cylinder,
    String? item,
    String? computer,
    int? channel,
  }) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: id,
            label: id,
            tankRole: 'backGas',
            createdAt: t,
            updatedAt: t,
            diverId: Value(owner),
            transmitterSerial: Value(serial),
            equipmentId: Value(cylinder),
            transmitterEquipmentId: Value(item),
            diveComputerId: Value(computer),
            channelIndex: Value(channel),
          ),
        );
  }

  Future<Set<String>> pending(String entityType) async => {
    for (final r
        in await db
            .customSelect(
              'SELECT record_id FROM sync_records WHERE entity_type = ?',
              variables: [Variable<String>(entityType)],
            )
            .get())
      r.read<String>('record_id'),
  };

  Future<String?> computerOwner(String id) async => (await (db.select(
    db.diveComputers,
  )..where((t) => t.id.equals(id))).getSingle()).diverId;

  Future<String?> transmitterOwner(String id) async => (await (db.select(
    db.transmitters,
  )..where((t) => t.id.equals(id))).getSingle()).diverId;

  setUp(() async {
    db = await setUpTestDatabase();
    service = EquipmentTransferService();
    for (final d in ['bill', 'anna', 'tom']) {
      await addDiver(d);
    }
  });

  tearDown(tearDownTestDatabase);

  test('moves a linked dive computer and transmitters', () async {
    await addItem('perdix', 'bill');
    await addItem('tank', 'bill');
    await addComputer('c1', 'bill', gear: 'perdix');
    await addTransmitter('tx1', 'bill', serial: 'A1', cylinder: 'tank');
    final result = await service.transfer(
      equipmentIds: ['perdix', 'tank'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    expect(result.computersMoved, 1);
    expect(result.transmittersMoved, 1);
    expect(await computerOwner('c1'), 'anna');
    expect(await transmitterOwner('tx1'), 'anna');
    expect(await pending('diveComputers'), {'c1'});
    expect(await pending('transmitters'), {'tx1'});
    expect(result.movedTransmitterIds, ['tx1']);
  });

  test('a failed rescan after the commit does not fail the transfer', () async {
    final rescanned = <String>[];
    final failing = EquipmentTransferService(
      rescanTransmitters: (ids) async {
        rescanned.addAll(ids);
        throw StateError('rescan failed');
      },
    );
    await addItem('tank', 'bill');
    await addTransmitter('tx1', 'bill', serial: 'A1', cylinder: 'tank');
    final result = await failing.transfer(
      equipmentIds: ['tank'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    expect(result.itemsMoved, 1);
    expect(rescanned, ['tx1']);
    expect(await transmitterOwner('tx1'), 'anna');
  });

  test('moveRegistry false leaves registry rows with the old owner', () async {
    await addItem('perdix', 'bill');
    await addComputer('c1', 'bill', gear: 'perdix');
    await service.transfer(
      equipmentIds: ['perdix'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
      moveRegistry: false,
    );
    expect(await computerOwner('c1'), 'bill');
  });

  test('a clashing transmitter stays and is counted', () async {
    await addItem('tank', 'bill');
    await addTransmitter('tx1', 'bill', serial: 'A1', cylinder: 'tank');
    await addTransmitter('tx2', 'anna', serial: 'A1');
    final result = await service.transfer(
      equipmentIds: ['tank'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    expect(result.transmittersKept, 1);
    expect(result.transmittersMoved, 0);
    expect(await transmitterOwner('tx1'), 'bill');
  });

  test('preview lists the unit, registry rows and clashes', () async {
    await addItem('ccr', 'bill');
    await addItem('cell', 'bill', host: 'ccr');
    await addItem('mask', 'tom');
    await addComputer('c1', 'bill', gear: 'ccr');
    await addTransmitter('tx1', 'bill', serial: 'A1', item: 'cell');
    await addTransmitter('tx2', 'anna', serial: 'A1');
    final p = await service.preview(
      equipmentIds: ['cell', 'mask'],
      actingDiverId: 'bill',
      toDiverId: 'anna',
    );
    expect(p.unitIds.toSet(), {'ccr', 'cell'});
    expect(p.skippedNotOwned, 1);
    expect(p.computers.map((c) => c.id), ['c1']);
    expect(p.transmitters.single.id, 'tx1');
    expect(p.transmitters.single.clashes, isTrue);
  });

  test('preview without a target reports no clashes', () async {
    await addItem('tank', 'bill');
    await addTransmitter('tx1', 'bill', serial: 'A1', cylinder: 'tank');
    await addTransmitter('tx2', 'anna', serial: 'A1');
    final p = await service.preview(
      equipmentIds: ['tank'],
      actingDiverId: 'bill',
    );
    expect(p.transmitters.single.clashes, isFalse);
    expect(p.hasRegistry, isTrue);
  });

  // Without a serial, a transmitter is known only by its computer and
  // channel; moving it while that computer stays would key the new owner's
  // entry to another profile's computer.
  test(
    'a serial-less transmitter stays when its computer does not move',
    () async {
      await addItem('tank', 'bill');
      await addComputer('c1', 'bill');
      await addTransmitter(
        'tx1',
        'bill',
        cylinder: 'tank',
        computer: 'c1',
        channel: 2,
      );
      final result = await service.transfer(
        equipmentIds: ['tank'],
        toDiverId: 'anna',
        actingDiverId: 'bill',
      );
      expect(result.transmittersKept, 1);
      expect(result.transmittersMoved, 0);
      expect(await transmitterOwner('tx1'), 'bill');
    },
  );

  test('a serial-less transmitter moves with its computer', () async {
    await addItem('perdix', 'bill');
    await addItem('tank', 'bill');
    await addComputer('c1', 'bill', gear: 'perdix');
    await addTransmitter(
      'tx1',
      'bill',
      cylinder: 'tank',
      computer: 'c1',
      channel: 2,
    );
    final result = await service.transfer(
      equipmentIds: ['perdix', 'tank'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    expect(result.transmittersMoved, 1);
    expect(await transmitterOwner('tx1'), 'anna');
  });

  test(
    'a transmitter with a serial moves even if its computer stays',
    () async {
      await addItem('tank', 'bill');
      await addComputer('c1', 'bill');
      await addTransmitter(
        'tx1',
        'bill',
        serial: 'A1',
        cylinder: 'tank',
        computer: 'c1',
        channel: 2,
      );
      final result = await service.transfer(
        equipmentIds: ['tank'],
        toDiverId: 'anna',
        actingDiverId: 'bill',
      );
      expect(result.transmittersMoved, 1);
    },
  );
}
