import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/services/cylinder_spec_attributes.dart';

void main() {
  test('writes curated keys', () {
    final attrs = cylinderSpecAttributes(
      volumeL: 11.1,
      workingPressureBar: 207,
      material: TankMaterial.carbonFiber,
      valveChoice: 'din',
      suitInflation: true,
    );
    final byKey = {for (final a in attrs) a.key: a};
    expect(byKey.keys, {
      EquipmentAttrKeys.volumeL,
      EquipmentAttrKeys.workingPressureBar,
      EquipmentAttrKeys.tankMaterial,
      'valve_type',
      EquipmentAttrKeys.cylinderUse,
    });
    expect(byKey[EquipmentAttrKeys.volumeL]!.valueNum, 11.1);
    expect(byKey[EquipmentAttrKeys.workingPressureBar]!.valueNum, 207);
    expect(
      byKey[EquipmentAttrKeys.tankMaterial]!.valueText,
      'carbon_composite',
    );
    expect(byKey['valve_type']!.valueText, 'din');
    expect(byKey[EquipmentAttrKeys.cylinderUse]!.valueText, 'suit_inflation');
    expect(attrs.every((a) => a.equipmentId == ''), isTrue);
  });

  test('nothing given writes nothing', () {
    expect(cylinderSpecAttributes(), isEmpty);
  });

  test('a breathing gas cylinder records no cylinder use', () {
    final attrs = cylinderSpecAttributes(volumeL: 11.1);
    expect(attrs.map((a) => a.key), [EquipmentAttrKeys.volumeL]);
  });

  test(
    'a cylinder made from a Twin Set tank is worn as a twin set (#4641)',
    () {
      final attrs = cylinderSpecAttributes(volumeL: 24, twinSet: true);
      final byKey = {for (final a in attrs) a.key: a};
      expect(byKey[EquipmentAttrKeys.wornAs]!.valueText, kWornAsTwinSet);
      expect(byKey.containsKey(EquipmentAttrKeys.cylinderUse), isFalse);
    },
  );
}
