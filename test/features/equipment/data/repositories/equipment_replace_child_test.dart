import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// Fails the retire half of a replacement, to prove the create half is
/// undone with it.
class _RetireFails extends EquipmentRepository {
  @override
  Future<void> retireEquipment(String id) async {
    throw StateError('retire failed');
  }
}

/// Replacing a child (condition phase 4a): the old one retires today and a
/// successor takes its slot with today's install date.
void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<int> pending(String id) async {
    final rows = await db.select(db.syncRecords).get();
    return rows
        .where((r) => r.entityType == 'equipment' && r.recordId == id)
        .length;
  }

  test('retires the old child and creates its successor in the slot', () async {
    final ccr = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'CCR', type: EquipmentType.rebreather),
    );
    final old = await repo.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Cell 2',
        type: EquipmentType.o2Cell,
        brand: 'Molecular',
        model: 'PSR-11-39-MD',
        serialNumber: 'X123',
        notes: 'bought in Malta',
        parentEquipmentId: ccr.id,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.cellSlot,
            valueNum: 2,
          ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.installedDate,
            valueNum: DateTime(2026, 1, 1).millisecondsSinceEpoch.toDouble(),
          ),
        ],
      ),
    );
    await db.delete(db.syncRecords).go();

    final now = DateTime(2026, 9, 10);
    final fresh = await repo.replaceChild(old, now: now);

    expect(fresh.id, isNot(old.id));
    expect(fresh.name, 'Cell 2');
    expect(fresh.type, EquipmentType.o2Cell);
    expect(fresh.brand, 'Molecular');
    expect(fresh.model, 'PSR-11-39-MD');
    expect(fresh.parentEquipmentId, ccr.id);
    expect(fresh.serialNumber, isNull);
    expect(fresh.notes, '');
    expect(fresh.isActive, isTrue);
    expect(fresh.status, EquipmentStatus.active);
    expect(fresh.attrNum(EquipmentAttrKeys.cellSlot), 2);
    expect(fresh.installedDate, now);

    final stored = await repo.getEquipmentById(fresh.id);
    expect(stored!.attrNum(EquipmentAttrKeys.cellSlot), 2);
    expect(stored.installedDate, now);

    final retired = await repo.getEquipmentById(old.id);
    expect(retired!.isActive, isFalse);
    expect(retired.status, EquipmentStatus.retired);

    expect(await pending(old.id), greaterThanOrEqualTo(1));
    expect(await pending(fresh.id), greaterThanOrEqualTo(1));
    final active = await repo.getChildEquipment(ccr.id);
    expect(active.map((c) => c.id), [fresh.id]);
  });

  test('a replaced battery keeps its chemistry, not its receipt', () async {
    // The successor is the same kind of part: its physical spec carries
    // over. Its purchase record and install date are its own.
    final light = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Light', type: EquipmentType.light),
    );
    final old = await repo.createEquipment(
      EquipmentItem(
        id: '',
        name: '21700',
        type: EquipmentType.battery,
        parentEquipmentId: light.id,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'battery_type',
            valueText: 'lithium_ion',
          ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.rechargeable,
            valueNum: 1,
          ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.retailer,
            valueText: 'Dive shop',
          ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.installedDate,
            valueNum: DateTime(2025, 1, 1).millisecondsSinceEpoch.toDouble(),
          ),
        ],
      ),
    );
    final now = DateTime(2026, 9, 10);
    final fresh = await repo.replaceChild(old, now: now);
    final stored = (await repo.getEquipmentById(fresh.id))!;
    String? text(String key) =>
        stored.attributes.where((a) => a.key == key).firstOrNull?.valueText;
    expect(text('battery_type'), 'lithium_ion');
    expect(stored.attrNum(EquipmentAttrKeys.rechargeable), 1);
    expect(text(EquipmentAttrKeys.retailer), isNull);
    expect(stored.installedDate, now);
  });

  Future<(EquipmentItem, EquipmentItem)> ccrWithCell() async {
    final ccr = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'CCR', type: EquipmentType.rebreather),
    );
    final cell = await repo.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Cell 1',
        type: EquipmentType.o2Cell,
        parentEquipmentId: ccr.id,
      ),
    );
    return (ccr, cell);
  }

  Future<int> equipmentRows() async =>
      (await db.select(db.equipment).get()).length;

  test('a failed retire leaves no successor behind', () async {
    final (ccr, cell) = await ccrWithCell();
    final rowsBefore = await equipmentRows();
    await db.delete(db.syncRecords).go();

    await expectLater(_RetireFails().replaceChild(cell), throwsStateError);

    // Both halves roll back together: one active part in the slot, and
    // nothing new staged for sync.
    final active = await repo.getChildEquipment(ccr.id);
    expect(active.map((c) => c.id), [cell.id]);
    expect(await equipmentRows(), rowsBefore);
    expect(await db.select(db.syncRecords).get(), isEmpty);
  });

  test('an item with no parent is refused and nothing is written', () async {
    final loose = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Cell', type: EquipmentType.o2Cell),
    );
    final rowsBefore = await equipmentRows();

    await expectLater(repo.replaceChild(loose), throwsArgumentError);
    expect(await equipmentRows(), rowsBefore);
    expect((await repo.getEquipmentById(loose.id))!.isActive, isTrue);
  });

  test('a legacy row retired by status alone is refused', () async {
    // Older rows can be retired or sold with isActive left true; the
    // repository treats both statuses as gone.
    final (_, cell) = await ccrWithCell();
    await (db.update(db.equipment)..where((t) => t.id.equals(cell.id))).write(
      const EquipmentCompanion(status: Value('sold')),
    );
    await expectLater(repo.replaceChild(cell), throwsStateError);
  });

  test('a child already retired is refused and nothing is written', () async {
    final (_, cell) = await ccrWithCell();
    await repo.retireEquipment(cell.id);
    final rowsBefore = await equipmentRows();

    // The caller's copy still says active; the stored row decides.
    await expectLater(repo.replaceChild(cell), throwsStateError);
    expect(await equipmentRows(), rowsBefore);
  });

  test(
    'the retired row keeps the real clock when install is backdated',
    () async {
      // installed_date is a date the diver may backdate; updated_at is the
      // sync clock and must never move backwards, so the two are allowed
      // to disagree.
      final (_, cell) = await ccrWithCell();
      final before = DateTime.now().millisecondsSinceEpoch;
      await repo.replaceChild(cell, now: DateTime(2020, 1, 1));
      final row = await (db.select(
        db.equipment,
      )..where((t) => t.id.equals(cell.id))).getSingle();
      expect(row.updatedAt, greaterThanOrEqualTo(before));
    },
  );
}
