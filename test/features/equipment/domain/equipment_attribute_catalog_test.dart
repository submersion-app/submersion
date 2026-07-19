import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

void main() {
  test('every equipment type resolves to a definition list', () {
    for (final type in EquipmentType.values) {
      final defs = EquipmentAttributeCatalog.attributesFor(type);
      // Universal attrs are always present.
      expect(
        defs.map((d) => d.key),
        containsAll(['buoyancy_kg', 'dry_weight_kg']),
        reason: '${type.name} missing universal attributes',
      );
      // No duplicate keys within a type.
      final keys = defs.map((d) => d.key).toList();
      expect(
        keys.toSet().length,
        keys.length,
        reason: '${type.name} has duplicate keys',
      );
    }
  });

  test('type-specific expectations', () {
    List<String> keysFor(EquipmentType t) =>
        EquipmentAttributeCatalog.attributesFor(t).map((d) => d.key).toList();

    expect(
      keysFor(EquipmentType.wetsuit),
      containsAll(['size', 'thickness_mm', 'suit_style']),
    );
    expect(
      keysFor(EquipmentType.tank),
      containsAll([
        'volume_l',
        'working_pressure_bar',
        'tank_material',
        'valve_type',
        'tank_identifier',
        'last_visual_inspection',
        'last_hydro_test',
      ]),
    );
    expect(
      keysFor(EquipmentType.other),
      unorderedEquals(['buoyancy_kg', 'dry_weight_kg']),
    );
  });

  test('choice kinds always have at least two options', () {
    for (final type in EquipmentType.values) {
      for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
        if (def.kind == AttributeKind.choice) {
          expect(
            def.choiceKeys.length,
            greaterThanOrEqualTo(2),
            reason: '${def.key} has too few choices',
          );
        } else {
          expect(
            def.choiceKeys,
            isEmpty,
            reason: '${def.key} is not a choice but has choiceKeys',
          );
        }
      }
    }
  });

  test('number kinds carry a dimension where units apply', () {
    final expectDim = {
      'volume_l': AttributeDimension.volumeL,
      'working_pressure_bar': AttributeDimension.pressureBar,
      'lift_capacity_kg': AttributeDimension.massKg,
      'buoyancy_kg': AttributeDimension.massKg,
      'dry_weight_kg': AttributeDimension.massKg,
      'length_m': AttributeDimension.lengthM,
      'line_length_m': AttributeDimension.lengthM,
      'depth_rating_m': AttributeDimension.depthM,
      'thickness_mm': AttributeDimension.thicknessMm,
    };
    expectDim.forEach((key, dim) {
      expect(
        EquipmentAttributeCatalog.defFor(key)?.dimension,
        dim,
        reason: key,
      );
    });
    // lumens is a dimensionless number.
    expect(
      EquipmentAttributeCatalog.defFor('lumens')?.dimension,
      AttributeDimension.none,
    );
  });

  test('parsePrimaryThickness handles designations', () {
    expect(parsePrimaryThickness('5'), 5.0);
    expect(parsePrimaryThickness('5/4'), 5.0);
    expect(parsePrimaryThickness('7/5/3'), 7.0);
    expect(parsePrimaryThickness('6mm'), 6.0);
    expect(parsePrimaryThickness('2.5'), 2.5);
    expect(parsePrimaryThickness(' 5/4 '), 5.0);
    expect(parsePrimaryThickness('thin'), isNull);
    expect(parsePrimaryThickness(''), isNull);
  });

  test('isValidThicknessDesignation accepts what the migration preserves', () {
    // Legacy values the v124 migration copies verbatim into valueText must
    // pass the edit-form validator, or the item can never be saved again.
    expect(isValidThicknessDesignation('6mm'), isTrue);
    expect(isValidThicknessDesignation('6 mm'), isTrue);
    expect(isValidThicknessDesignation('5/4/3'), isTrue);
    expect(isValidThicknessDesignation('8/7/6mm'), isTrue);
    expect(isValidThicknessDesignation('4,3'), isTrue);
    expect(isValidThicknessDesignation('6-3'), isTrue);
    expect(isValidThicknessDesignation('2.5'), isTrue);
    expect(isValidThicknessDesignation(' 5 / 4 '), isTrue);
    // Empty is valid (the field is optional).
    expect(isValidThicknessDesignation(''), isTrue);
    // Non-numeric garbage is still rejected.
    expect(isValidThicknessDesignation('thin'), isFalse);
    expect(isValidThicknessDesignation('abc'), isFalse);
  });
}
