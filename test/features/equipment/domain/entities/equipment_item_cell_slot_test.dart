import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// A dive computer reports cells as o2Sensor1 to o2Sensor6, so only 1 to 6
/// is a slot a reading can match; the form takes any number.
void main() {
  EquipmentItem cellIn(double? slot) => EquipmentItem(
    id: 'c',
    name: 'c',
    type: EquipmentType.o2Cell,
    attributes: [
      if (slot != null)
        EquipmentAttribute.curated(
          equipmentId: 'c',
          key: EquipmentAttrKeys.cellSlot,
          valueNum: slot,
        ),
    ],
  );

  test('1 to 6 is a slot', () {
    expect(cellIn(1).cellSlot, 1);
    expect(cellIn(6).cellSlot, 6);
    expect(cellIn(2.6).cellSlot, 3, reason: 'rounded like the form');
  });

  test('anything else is no slot', () {
    expect(cellIn(null).cellSlot, isNull);
    expect(cellIn(0).cellSlot, isNull);
    expect(cellIn(7).cellSlot, isNull);
    expect(cellIn(-1).cellSlot, isNull);
  });
}
