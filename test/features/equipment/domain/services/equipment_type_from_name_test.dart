import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/services/equipment_type_from_name.dart';

void main() {
  group('typeFromName', () {
    test('reads a wetsuit and the one thickness its name states', () {
      expect(typeFromName('7mm Wetsuit'), (
        type: EquipmentType.wetsuit,
        thickness: '7mm',
      ));
    });

    test('reads a bare thickness, as old CSV suit values were stored', () {
      expect(typeFromName('7mm'), (
        type: EquipmentType.wetsuit,
        thickness: '7mm',
      ));
    });

    test('reads a drysuit with no thickness', () {
      expect(typeFromName('Fourth Element Drysuit'), (
        type: EquipmentType.drysuit,
        thickness: null,
      ));
    });

    test('reads a shorty as a wetsuit', () {
      expect(typeFromName('Shorty'), (
        type: EquipmentType.wetsuit,
        thickness: null,
      ));
    });

    test('lets the suit reader settle a semi-dry the mapper calls dry', () {
      expect(typeFromName('Semi dry suit'), (
        type: EquipmentType.wetsuit,
        thickness: null,
      ));
    });

    test('reads the layers worn under or instead of a suit', () {
      expect(typeFromName('Thermal undersuit')?.type, EquipmentType.undersuit);
      expect(
        typeFromName('Fourth Element Thermals')?.type,
        EquipmentType.baselayer,
      );
      expect(typeFromName('Rash guard')?.type, EquipmentType.rashGuard);
    });

    test('reads an accessory, not the suit it goes with', () {
      expect(typeFromName('5mm hood'), (
        type: EquipmentType.hood,
        thickness: null,
      ));
      expect(typeFromName('Dry gloves')?.type, EquipmentType.gloves);
    });

    test('keeps a specific non-suit item over a suit word or thickness', () {
      expect(
        typeFromName('Drysuit thigh pocket')?.type,
        EquipmentType.gearPocket,
      );
      expect(typeFromName('O-ring kit 2.5mm'), (
        type: EquipmentType.tool,
        thickness: null,
      ));
    });

    test('reads any other type the name states', () {
      expect(typeFromName('Apeks fins')?.type, EquipmentType.fins);
      expect(typeFromName('Backup regulator')?.type, EquipmentType.regulator);
    });

    test('proposes nothing when the name does not say what it is', () {
      expect(typeFromName('Hydros Pro'), isNull);
      expect(typeFromName('Spare parts bag'), isNull);
    });

    test('proposes nothing for a blank name', () {
      expect(typeFromName(''), isNull);
      expect(typeFromName('   '), isNull);
    });
  });
}
