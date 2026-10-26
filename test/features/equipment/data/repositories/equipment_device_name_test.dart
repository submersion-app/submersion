import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// One name (issue #3676): a device's Equipment item is its only entry, so
/// the item's name and notes are the device's.
void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> item(EquipmentType type) =>
      repo.createEquipment(EquipmentItem(id: '', name: 'Old', type: type));

  test('renaming a computer item renames its computer and stages it', () async {
    final gear = await item(EquipmentType.computer);
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'c1',
            name: 'Old',
            equipmentId: Value(gear.id),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db.delete(db.syncRecords).go();

    await repo.updateEquipment(
      gear.copyWith(name: 'Wrist Teric', notes: 'Left arm.'),
    );

    final c = await (db.select(
      db.diveComputers,
    )..where((t) => t.id.equals('c1'))).getSingle();
    expect(c.name, 'Wrist Teric');
    expect(c.notes, 'Left arm.');
    expect(
      (await db.select(db.syncRecords).get()).map((r) => r.entityType),
      contains('diveComputers'),
    );
  });

  test('renaming a transmitter item relabels its rows', () async {
    final gear = await item(EquipmentType.transmitter);
    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: 'tx1',
            label: 'Old',
            tankRole: 'backGas',
            transmitterSerial: const Value('4A21F'),
            transmitterEquipmentId: Value(gear.id),
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    await repo.updateEquipment(gear.copyWith(name: 'Back gas AL80'));

    final row = await (db.select(
      db.transmitters,
    )..where((t) => t.id.equals('tx1'))).getSingle();
    expect(row.label, 'Back gas AL80');
  });

  test('saving an item with no device writes no device row', () async {
    final gear = await item(EquipmentType.mask);
    await db.delete(db.syncRecords).go();

    await repo.updateEquipment(gear.copyWith(name: 'New mask'));

    expect((await db.select(db.syncRecords).get()).map((r) => r.entityType), [
      'equipment',
    ]);
  });
}
