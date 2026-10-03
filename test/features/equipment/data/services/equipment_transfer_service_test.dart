import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';

import '../../../../helpers/test_database.dart';

/// Ownership transfer between diver profiles (issue #2852).
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

  Future<void> addItem(
    String id,
    String owner, {
    String? host,
    bool active = true,
  }) async {
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
            isActive: Value(active),
          ),
        );
  }

  Future<String?> ownerOf(String id) async => (await (db.select(
    db.equipment,
  )..where((t) => t.id.equals(id))).getSingle()).diverId;

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

  Future<Set<String>> tombstones(String entityType) async => {
    for (final r in await db.select(db.deletionLog).get())
      if (r.entityType == entityType) r.recordId,
  };

  Future<List<EquipmentOwnershipEventRow>> events(String id) => (db.select(
    db.equipmentOwnershipEvents,
  )..where((t) => t.equipmentId.equals(id))).get();

  setUp(() async {
    db = await setUpTestDatabase();
    service = EquipmentTransferService();
    for (final d in ['bill', 'anna', 'tom']) {
      await addDiver(d);
    }
  });

  tearDown(tearDownTestDatabase);

  test('moves the whole unit and marks every item pending', () async {
    await addItem('ccr', 'bill');
    await addItem('cell', 'bill', host: 'ccr');
    final result = await service.transfer(
      equipmentIds: ['cell'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    expect(result.itemsMoved, 2);
    expect(await ownerOf('ccr'), 'anna');
    expect(await ownerOf('cell'), 'anna');
    expect(await pending('equipment'), containsAll(['ccr', 'cell']));
  });

  test('writes one transferred event per item and no share events', () async {
    await addItem('light', 'bill');
    await service.transfer(
      equipmentIds: ['light'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    final rows = await events('light');
    expect(rows, hasLength(1));
    expect(rows.single.kind, 'transferred');
    expect(rows.single.fromDiverId, 'bill');
    expect(rows.single.toDiverId, 'anna');
    expect(await pending('equipmentOwnershipEvents'), {rows.single.id});
  });

  test('keepAccess adds a fresh share for the old owner', () async {
    await addItem('light', 'bill');
    await service.transfer(
      equipmentIds: ['light'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    final shares = await db.select(db.equipmentShares).get();
    expect(shares.map((s) => (s.equipmentId, s.diverId)), [('light', 'bill')]);
    expect(await pending('equipmentShares'), {shares.single.id});
  });

  test('without keepAccess the old owner gets no share', () async {
    await addItem('light', 'bill');
    await service.transfer(
      equipmentIds: ['light'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
      keepAccess: false,
    );
    expect(await db.select(db.equipmentShares).get(), isEmpty);
  });

  test(
    'the target share is deleted with a tombstone, other sharees stay',
    () async {
      await addItem('light', 'bill');
      await EquipmentShareRepository().shareMany(
        equipmentIds: ['light'],
        diverIds: ['anna', 'tom'],
        actingDiverId: 'bill',
      );
      final annaShare = (await (db.select(
        db.equipmentShares,
      )..where((t) => t.diverId.equals('anna'))).getSingle()).id;
      await service.transfer(
        equipmentIds: ['light'],
        toDiverId: 'anna',
        actingDiverId: 'bill',
        keepAccess: false,
      );
      final shares = await db.select(db.equipmentShares).get();
      expect(shares.map((s) => s.diverId), ['tom']);
      expect(await tombstones('equipmentShares'), contains(annaShare));
      final kinds = (await events('light')).map((e) => e.kind);
      expect(kinds.where((k) => k == 'unshared'), isEmpty);
    },
  );

  test('items the acting profile does not own are skipped', () async {
    await addItem('light', 'bill');
    await addItem('mask', 'tom');
    final result = await service.transfer(
      equipmentIds: ['light', 'mask'],
      toDiverId: 'anna',
      actingDiverId: 'bill',
    );
    expect(result.itemsMoved, 1);
    expect(result.skippedNotOwned, 1);
    expect(await ownerOf('mask'), 'tom');
  });

  test('a transfer to the current owner changes nothing', () async {
    await addItem('light', 'bill');
    final result = await service.transfer(
      equipmentIds: ['light'],
      toDiverId: 'bill',
      actingDiverId: 'bill',
    );
    expect(result.itemsMoved, 0);
    expect(await events('light'), isEmpty);
  });

  test(
    'a retired item moves with its unit; dives and sets are untouched',
    () async {
      await addItem('ccr', 'bill');
      await addItem('oldcell', 'bill', host: 'ccr', active: false);
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'd1',
              diverId: const Value('bill'),
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'ccr'),
          );
      await db
          .into(db.equipmentSets)
          .insert(
            EquipmentSetsCompanion.insert(
              id: 's1',
              name: 'kit',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('bill'),
            ),
          );
      await db
          .into(db.equipmentSetItems)
          .insert(
            EquipmentSetItemsCompanion.insert(setId: 's1', equipmentId: 'ccr'),
          );
      await service.transfer(
        equipmentIds: ['ccr'],
        toDiverId: 'anna',
        actingDiverId: 'bill',
      );
      expect(await ownerOf('oldcell'), 'anna');
      expect(await db.select(db.diveEquipment).get(), hasLength(1));
      expect(await db.select(db.equipmentSetItems).get(), hasLength(1));
    },
  );

  test('a missing target rolls the whole transfer back', () async {
    await addItem('light', 'bill');
    await expectLater(
      service.transfer(
        equipmentIds: ['light'],
        toDiverId: 'ghost',
        actingDiverId: 'bill',
      ),
      throwsA(anything),
    );
    expect(await ownerOf('light'), 'bill');
    expect(await events('light'), isEmpty);
    expect(await db.select(db.equipmentShares).get(), isEmpty);
  });

  test(
    "a transfer hands the old owner's fills on its cylinders to the new owner",
    () async {
      await addItem('tank', 'bill');
      const t = 1000;
      await db
          .into(db.cylinderFills)
          .insert(
            CylinderFillsCompanion.insert(
              id: 'fill1',
              passportId: 'pp1',
              filledAt: t,
              o2Percent: 32,
              createdAt: t,
              updatedAt: t,
              diverId: const Value('bill'),
              equipmentId: const Value('tank'),
            ),
          );
      await service.transfer(
        equipmentIds: ['tank'],
        toDiverId: 'anna',
        actingDiverId: 'bill',
        keepAccess: false,
      );
      final fill = await (db.select(
        db.cylinderFills,
      )..where((f) => f.id.equals('fill1'))).getSingle();
      expect(fill.diverId, 'anna');
      expect(await pending('cylinderFills'), {'fill1'});
    },
  );
}
