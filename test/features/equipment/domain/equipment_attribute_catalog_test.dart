import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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
    // The drysuit layers (#1537) are rated by warmth, not by millimetres:
    // asking for thickness_mm would be the wrong question for a garment sold
    // as "400g Thinsulate".
    for (final type in [EquipmentType.undersuit, EquipmentType.baselayer]) {
      expect(
        keysFor(type),
        containsAll(['size', 'insulation_level', 'fill_material']),
        reason: type.name,
      );
      expect(keysFor(type), isNot(contains('thickness_mm')), reason: type.name);
    }
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

  group('dpv attributes', () {
    test('exposes the curated dpv keys plus the universal ones', () {
      final keys = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.dpv,
      ).map((d) => d.key).toList();

      expect(keys, [
        'dpv_style',
        'burn_time_h',
        'battery_type',
        'battery_capacity_wh',
        'motor_type',
        'speed_mps',
        'depth_rating_m',
        'buoyancy_kg',
        'dry_weight_kg',
      ]);
    });

    test('speed carries the speed dimension so it converts for the diver', () {
      final def = EquipmentAttributeCatalog.defFor('speed_mps');
      expect(def, isNotNull);
      expect(def!.kind, AttributeKind.number);
      expect(def.dimension, AttributeDimension.speedMps);
    });

    test('burn time carries the duration dimension so it reads in minutes', () {
      // A scooter's rated run time is quoted in minutes, not fractions of an
      // hour (issue #1096); storage stays in hours, the dimension converts.
      final def = EquipmentAttributeCatalog.defFor('burn_time_h');
      expect(def, isNotNull);
      expect(def!.kind, AttributeKind.number);
      expect(def.dimension, AttributeDimension.durationH);
    });

    test('battery capacity is a dimensionless number', () {
      // Watt-hours are watt-hours in every market, the same call
      // scrubber_duration_h makes.
      final def = EquipmentAttributeCatalog.defFor('battery_capacity_wh');
      expect(def, isNotNull);
      expect(def!.kind, AttributeKind.number);
      expect(def.dimension, AttributeDimension.none);
    });

    test('reuses the shared depth_rating_m definition', () {
      // Same concept as the camera and rebreather entries, so it must reuse
      // the one key rather than minting a DPV-specific twin.
      final def = EquipmentAttributeCatalog.defFor('depth_rating_m');
      expect(def, isNotNull);
      expect(def!.dimension, AttributeDimension.depthM);
      expect(
        EquipmentAttributeCatalog.attributesFor(
          EquipmentType.camera,
        ).map((d) => d.key),
        contains('depth_rating_m'),
      );
    });

    test('choice options are the ones divers actually pick between', () {
      expect(EquipmentAttributeCatalog.defFor('dpv_style')!.choiceKeys, [
        'tow_behind',
        'ride_on',
        'handheld',
      ]);
      expect(EquipmentAttributeCatalog.defFor('battery_type')!.choiceKeys, [
        'lithium_ion',
        'nimh',
        'lead_acid',
      ]);
      expect(EquipmentAttributeCatalog.defFor('motor_type')!.choiceKeys, [
        'brushless',
        'brushed',
      ]);
    });

    test('every dpv attribute and option resolves to a localized label', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      for (final def in EquipmentAttributeCatalog.attributesFor(
        EquipmentType.dpv,
      )) {
        expect(
          attributeLabel(l10n, def.key),
          isNot(def.key),
          reason: 'missing attrLabel_${def.key}',
        );
        for (final option in def.choiceKeys) {
          expect(
            attributeChoiceLabel(l10n, def.key, option),
            isNot(option),
            reason: 'missing attrChoice_${def.key}_$option',
          );
        }
      }
    });
  });

  group('the #1518 equipment types', () {
    // Five types added for large/team/family inventories. The sixth the issue
    // asked for, a thermal undergarment, landed on main first as `undersuit`
    // and `baselayer` (#1537), so this branch drops its own rather than
    // offering the diver two names for one garment. Each one is asserted
    // as an exact ordered key list rather than a `containsAll`, because the
    // order is what the edit form renders and a silently dropped field would
    // otherwise pass.
    List<String> keysFor(EquipmentType t) =>
        EquipmentAttributeCatalog.attributesFor(t).map((d) => d.key).toList();

    test('all five exist with the names they are persisted under', () {
      // `equipment.type` is a text column holding `EquipmentType.name`, so
      // these strings are a storage contract: renaming one orphans every row
      // written before the rename.
      expect(EquipmentType.rashGuard.name, 'rashGuard');
      expect(EquipmentType.snorkel.name, 'snorkel');
      expect(EquipmentType.tool.name, 'tool');
      expect(EquipmentType.instrument.name, 'instrument');
      expect(EquipmentType.compass.name, 'compass');
    });

    test('a rash guard carries its sun specs, and not warmth', () {
      expect(keysFor(EquipmentType.rashGuard), [
        'size',
        'sleeve_length',
        'upf_rating',
        'buoyancy_kg',
        'dry_weight_kg',
      ]);
      // Warmth belongs to baselayer (#1537). Two ways to say "this one is
      // warm" is how one idea drifts into two words per locale.
      expect(
        keysFor(EquipmentType.rashGuard),
        isNot(contains(EquipmentAttrKeys.insulationLevel)),
      );
      expect(
        keysFor(EquipmentType.baselayer),
        contains(EquipmentAttrKeys.insulationLevel),
      );
      // A UPF number is a ratio, not a measurement, so it converts nowhere.
      expect(
        EquipmentAttributeCatalog.defFor('upf_rating')!.dimension,
        AttributeDimension.none,
      );
    });

    test('a snorkel carries the two things divers pick between', () {
      expect(keysFor(EquipmentType.snorkel), [
        'snorkel_type',
        'purge_valve',
        'buoyancy_kg',
        'dry_weight_kg',
      ]);
      expect(EquipmentAttributeCatalog.defFor('snorkel_type')!.choiceKeys, [
        'classic',
        'semi_dry',
        'dry',
        'foldable',
      ]);
    });

    test('a tool carries its kind and a free-text size', () {
      expect(keysFor(EquipmentType.tool), [
        'tool_type',
        'size',
        'buoyancy_kg',
        'dry_weight_kg',
      ]);
      // A spanner width or a hex key has no closed list to pick from.
      expect(
        EquipmentAttributeCatalog.defFor('size')!.kind,
        AttributeKind.text,
      );
    });

    test('an instrument carries a gauge range distinct from a tank one', () {
      expect(keysFor(EquipmentType.instrument), [
        'instrument_type',
        'gauge_max_pressure_bar',
        'depth_rating_m',
        'mount',
        'buoyancy_kg',
        'dry_weight_kg',
      ]);
      // Full scale of the dial, not a cylinder's working pressure: a 300 bar
      // gauge on a 232 bar tank is a different object, so the keys stay apart.
      expect(
        EquipmentAttributeCatalog.defFor('gauge_max_pressure_bar')!.dimension,
        AttributeDimension.pressureBar,
      );
      expect(
        EquipmentAttributeCatalog.defFor('working_pressure_bar')!.key,
        isNot('gauge_max_pressure_bar'),
      );
    });

    test('a compass carries the specs that decide where it works', () {
      expect(keysFor(EquipmentType.compass), [
        'compass_type',
        'balance_zone',
        'tilt_tolerance_deg',
        'mount',
        'buoyancy_kg',
        'dry_weight_kg',
      ]);
      expect(EquipmentAttributeCatalog.defFor('balance_zone')!.choiceKeys, [
        'northern',
        'southern',
        'global',
      ]);
      // Degrees convert nowhere.
      expect(
        EquipmentAttributeCatalog.defFor('tilt_tolerance_deg')!.dimension,
        AttributeDimension.none,
      );
    });

    test('the instrument and compass reuse the computer mount definition', () {
      // One key, one set of translations. Two twins carrying the same English
      // "Mount" would drift into different words per locale.
      final viaComputer = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.computer,
      ).firstWhere((d) => d.key == 'mount');
      for (final type in [EquipmentType.instrument, EquipmentType.compass]) {
        final def = EquipmentAttributeCatalog.attributesFor(
          type,
        ).firstWhere((d) => d.key == 'mount');
        expect(def.choiceKeys, viaComputer.choiceKeys, reason: type.name);
      }
    });

    test('every new attribute and option resolves to a localized label', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      const types = [
        EquipmentType.rashGuard,
        EquipmentType.snorkel,
        EquipmentType.tool,
        EquipmentType.instrument,
        EquipmentType.compass,
      ];
      for (final type in types) {
        for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
          expect(
            attributeLabel(l10n, def.key),
            isNot(def.key),
            reason: 'missing attrLabel_${def.key}',
          );
          for (final option in def.choiceKeys) {
            expect(
              attributeChoiceLabel(l10n, def.key, option),
              isNot(option),
              reason: 'missing attrChoice_${def.key}_$option',
            );
          }
        }
      }
    });
  });

  test('rebreather is a distinct equipment type with a stable name', () {
    expect(EquipmentType.values, contains(EquipmentType.rebreather));
    expect(EquipmentType.rebreather.name, 'rebreather');
    expect(EquipmentType.rebreather.displayName, 'Rebreather');
  });

  group('rebreather attributes', () {
    test('exposes the curated rebreather keys plus the universal ones', () {
      final keys = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.rebreather,
      ).map((d) => d.key).toList();

      expect(keys, [
        'unit_type',
        'mount_configuration',
        'scrubber_type',
        'scrubber_duration_h',
        'o2_cell_count',
        'diluent_cylinder_l',
        'o2_cylinder_l',
        'depth_rating_m',
        'buoyancy_kg',
        'dry_weight_kg',
      ]);
    });

    test('unit_type covers both CCR and SCR variants', () {
      final def = EquipmentAttributeCatalog.defFor('unit_type');
      expect(def, isNotNull);
      expect(def!.kind, AttributeKind.choice);
      expect(def.choiceKeys, [
        'eccr',
        'mccr',
        'hccr',
        'scr_cmf',
        'scr_pascr',
        'scr_escr',
      ]);
    });

    test('onboard cylinder attributes carry the volume dimension', () {
      for (final key in ['diluent_cylinder_l', 'o2_cylinder_l']) {
        final def = EquipmentAttributeCatalog.defFor(key);
        expect(def, isNotNull, reason: key);
        expect(def!.kind, AttributeKind.number, reason: key);
        expect(def.dimension, AttributeDimension.volumeL, reason: key);
      }
    });

    test('scrubber duration is dimensionless hours, not a unit-converted '
        'quantity', () {
      final def = EquipmentAttributeCatalog.defFor('scrubber_duration_h');
      expect(def!.kind, AttributeKind.number);
      expect(def.dimension, AttributeDimension.none);
    });

    testWidgets('every rebreather attribute and choice resolves to a label', (
      tester,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final defs = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.rebreather,
      );
      for (final def in defs) {
        expect(
          attributeLabel(l10n, def.key),
          isNot(def.key),
          reason: 'missing attrLabel_${def.key}',
        );
        for (final option in def.choiceKeys) {
          expect(
            attributeChoiceLabel(l10n, def.key, option),
            isNot(option),
            reason: 'missing attrChoice_${def.key}_$option',
          );
        }
      }
    });
  });
}
