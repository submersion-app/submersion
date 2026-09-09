import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The component types added for assemblies (issue #1487). Declaration
/// order is the dropdown order, so each family sits beside the thing it is
/// part of.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  int indexOf(EquipmentType t) => EquipmentType.values.indexOf(t);

  test('regulator parts follow the regulator', () {
    expect(
      indexOf(EquipmentType.firstStage),
      indexOf(EquipmentType.regulator) + 1,
    );
    expect(
      indexOf(EquipmentType.secondStage),
      indexOf(EquipmentType.regulator) + 2,
    );
    expect(indexOf(EquipmentType.hose), indexOf(EquipmentType.regulator) + 3);
  });

  test('harness parts follow the BCD', () {
    expect(indexOf(EquipmentType.backplate), indexOf(EquipmentType.bcd) + 1);
    expect(indexOf(EquipmentType.wing), indexOf(EquipmentType.bcd) + 2);
    expect(indexOf(EquipmentType.harness), indexOf(EquipmentType.bcd) + 3);
  });

  test('photo parts follow the camera', () {
    expect(indexOf(EquipmentType.housing), indexOf(EquipmentType.camera) + 1);
    expect(indexOf(EquipmentType.strobe), indexOf(EquipmentType.camera) + 2);
  });

  test(
    'each new type has a label, a non-generic icon, and its .name persisted',
    () {
      const added = {
        EquipmentType.firstStage: 'First Stage',
        EquipmentType.secondStage: 'Second Stage',
        EquipmentType.hose: 'Hose',
        EquipmentType.backplate: 'Backplate',
        EquipmentType.wing: 'Wing',
        EquipmentType.harness: 'Harness',
        EquipmentType.housing: 'Housing',
        EquipmentType.strobe: 'Strobe',
      };
      final generic = equipmentTypeIcon(EquipmentType.other);
      for (final entry in added.entries) {
        expect(
          entry.key.localizedName(l10n),
          entry.value,
          reason: entry.key.name,
        );
        expect(entry.key.displayName, entry.value, reason: entry.key.name);
        expect(equipmentTypeIcon(entry.key), isA<IconData>());
        expect(
          equipmentTypeIcon(entry.key),
          isNot(generic),
          reason: entry.key.name,
        );
      }
    },
  );

  test('the new types carry the attributes that make them useful', () {
    List<String> keysFor(EquipmentType t) =>
        EquipmentAttributeCatalog.attributesFor(t).map((d) => d.key).toList();
    expect(
      keysFor(EquipmentType.firstStage),
      containsAll(['connection', 'cold_water_rated']),
    );
    expect(keysFor(EquipmentType.secondStage), contains('cold_water_rated'));
    expect(keysFor(EquipmentType.hose), contains('hose_length_m'));
    expect(keysFor(EquipmentType.backplate), contains('plate_material'));
    expect(keysFor(EquipmentType.wing), contains('lift_capacity_kg'));
    expect(keysFor(EquipmentType.harness), contains('size'));
    expect(keysFor(EquipmentType.housing), contains('depth_rating_m'));
    expect(keysFor(EquipmentType.strobe), contains('depth_rating_m'));
    final hose = EquipmentAttributeCatalog.defFor('hose_length_m')!;
    expect(hose.dimension, AttributeDimension.lengthM);
  });
}
