import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

EquipmentItem _item(EquipmentType type, {String? wornAs}) => EquipmentItem(
  id: 'g1',
  name: 'D12',
  type: type,
  attributes: [
    if (wornAs != null)
      EquipmentAttribute.curated(
        equipmentId: 'g1',
        key: EquipmentAttrKeys.wornAs,
        valueText: wornAs,
      ),
  ],
);

void main() {
  group('isWornAsTwinSet (issue #4641)', () {
    test('a tank worn as a twin set is one', () {
      expect(
        _item(EquipmentType.tank, wornAs: kWornAsTwinSet).isWornAsTwinSet,
        isTrue,
      );
    });

    test('a back mounted or unmarked tank is not', () {
      expect(_item(EquipmentType.tank, wornAs: 'back').isWornAsTwinSet, false);
      expect(_item(EquipmentType.tank).isWornAsTwinSet, isFalse);
    });

    test('only a tank can be one', () {
      expect(
        _item(EquipmentType.bcd, wornAs: kWornAsTwinSet).isWornAsTwinSet,
        isFalse,
      );
    });
  });

  test('Worn as offers Twin set right after Back mount', () {
    final def = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.wornAs)!;
    expect(def.choiceKeys, [
      'back',
      'twin_set',
      'sidemount_left',
      'sidemount_right',
      'stage',
    ]);
    expect(kWornAsTwinSet, 'twin_set');
  });
}
