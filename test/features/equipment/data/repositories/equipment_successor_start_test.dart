import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Which later part took a replaced part's place. A slot defines the
/// place for cells; batteries have none, so the next battery is it.
void main() {
  EquipmentItem part(
    String id,
    EquipmentType type,
    DateTime installed, {
    int? slot,
  }) => EquipmentItem(
    id: id,
    name: id,
    type: type,
    parentEquipmentId: 'p',
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.installedDate,
        valueNum: installed.millisecondsSinceEpoch.toDouble(),
      ),
      if (slot != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.cellSlot,
          valueNum: slot.toDouble(),
        ),
    ],
  );

  test('a cell succeeds the earlier cell in its slot', () {
    final old = part('old', EquipmentType.o2Cell, DateTime(2025), slot: 1);
    final next = part('new', EquipmentType.o2Cell, DateTime(2026), slot: 1);
    final other = part('o', EquipmentType.o2Cell, DateTime(2025, 6), slot: 2);
    expect(
      EquipmentRepository.successorStart(old, [old, next, other]),
      next.parentDivesFrom,
    );
  });

  test('a cell with no slot has no successor', () {
    // Without a slot nothing says which later cell took its place; another
    // slotless cell must not cut its history short.
    final old = part('old', EquipmentType.o2Cell, DateTime(2025));
    final later = part('later', EquipmentType.o2Cell, DateTime(2026));
    expect(EquipmentRepository.successorStart(old, [old, later]), isNull);
  });

  test('a battery is succeeded by the next battery', () {
    final old = part('old', EquipmentType.battery, DateTime(2025));
    final next = part('new', EquipmentType.battery, DateTime(2026));
    expect(
      EquipmentRepository.successorStart(old, [old, next]),
      next.parentDivesFrom,
    );
  });
}
