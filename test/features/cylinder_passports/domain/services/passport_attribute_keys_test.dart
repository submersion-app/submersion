import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_attribute_keys.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

void main() {
  test('every material maps to a tank catalog choice', () {
    final choices = EquipmentAttributeCatalog.defFor(
      EquipmentAttrKeys.tankMaterial,
    )!.choiceKeys;
    for (final m in TankMaterial.values) {
      expect(choices, contains(tankMaterialChoiceKey(m)), reason: m.name);
    }
    expect(tankMaterialChoiceKey(TankMaterial.carbonFiber), 'carbon_composite');
  });

  test('every valve maps to a tank catalog choice', () {
    final choices = EquipmentAttributeCatalog.defFor('valve_type')!.choiceKeys;
    for (final v in PassportValve.values) {
      expect(choices, contains(valveChoiceKey(v)), reason: v.name);
    }
    expect(valveChoiceKey(PassportValve.convertible), 'convertible');
  });
}
