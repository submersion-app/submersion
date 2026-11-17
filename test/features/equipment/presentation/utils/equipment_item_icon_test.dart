import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';

EquipmentItem _tank({String? wornAs}) => EquipmentItem(
  id: 't1',
  name: 'D12',
  type: EquipmentType.tank,
  attributes: [
    if (wornAs != null)
      EquipmentAttribute.curated(
        equipmentId: 't1',
        key: EquipmentAttrKeys.wornAs,
        valueText: wornAs,
      ),
  ],
);

void main() {
  group('equipmentItemIcon (issue #4641)', () {
    test('a tank worn as a twin set shows the twin set icon', () {
      expect(
        equipmentItemIcon(_tank(wornAs: kWornAsTwinSet)),
        SubmersionIcons.tankTwinSet,
      );
    });

    test('any other tank shows the tank icon', () {
      expect(equipmentItemIcon(_tank()), MdiIcons.divingScubaTank);
      expect(
        equipmentItemIcon(_tank(wornAs: 'back')),
        MdiIcons.divingScubaTank,
      );
    });
  });

  group('equipmentIconFor', () {
    test('reads Worn as for a tank only', () {
      expect(
        equipmentIconFor(EquipmentType.tank, wornAs: kWornAsTwinSet),
        SubmersionIcons.tankTwinSet,
      );
      expect(
        equipmentIconFor(EquipmentType.bcd, wornAs: kWornAsTwinSet),
        equipmentTypeIcon(EquipmentType.bcd),
      );
      expect(
        equipmentIconFor(EquipmentType.tank),
        equipmentTypeIcon(EquipmentType.tank),
      );
    });
  });
}
