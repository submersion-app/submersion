import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

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
}
