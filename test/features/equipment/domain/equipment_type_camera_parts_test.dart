import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/constants/observation_tag_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/services/battery_cycles.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/children_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The photo rig's parts (issue #1997), completing the camera family that
/// #1487 started with Housing and Strobe, so a camera is assembled from its
/// parts the way a regulator and a BCD are.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  /// The whole family, in the order it sits beside the camera.
  const family = [
    EquipmentType.camera,
    EquipmentType.lens,
    EquipmentType.port,
    EquipmentType.housing,
    EquipmentType.trayHandle,
    EquipmentType.armClamp,
    EquipmentType.strobe,
    EquipmentType.videoLight,
    EquipmentType.floatArm,
  ];

  /// The types this issue adds.
  const added = {
    EquipmentType.lens: ('Lens', 'lens'),
    EquipmentType.port: ('Port', 'port'),
    EquipmentType.trayHandle: ('Tray / Handle', 'trayHandle'),
    EquipmentType.armClamp: ('Arm / Clamp', 'armClamp'),
    EquipmentType.videoLight: ('Video Light', 'videoLight'),
    EquipmentType.floatArm: ('Float Arm / Float', 'floatArm'),
  };

  test('the camera family is declared together, camera first', () {
    final start = EquipmentType.values.indexOf(EquipmentType.camera);
    expect(EquipmentType.values.sublist(start, start + family.length), family);
  });

  test('every list ordering keeps the camera family together', () {
    for (final table in [
      kHeadToToeTypeOrder,
      kDressingTypeOrder,
      kCanonicalTypeOrder,
    ]) {
      final start = table.indexOf(EquipmentType.camera);
      expect(table.sublist(start, start + family.length), family);
    }
  });

  test('each new part has a label, its own drawn icon and a stable .name', () {
    final icons = <IconData>{};
    for (final entry in added.entries) {
      final (label, name) = entry.value;
      expect(entry.key.localizedName(l10n), label, reason: name);
      expect(entry.key.displayName, label, reason: name);
      // `.name` is what `equipment.type` persists: a storage contract.
      expect(entry.key.name, name);
      final icon = equipmentTypeIcon(entry.key);
      expect(icon.fontFamily, SubmersionIcons.fontFamily, reason: name);
      icons.add(icon);
    }
    expect(icons, hasLength(added.length), reason: 'two parts share a glyph');
  });

  group('fields', () {
    final shared = {
      ...EquipmentAttributeCatalog.universal,
      ...EquipmentAttributeCatalog.purchase,
      ...EquipmentAttributeCatalog.appearance,
    }.map((d) => d.key).toSet();
    List<String> keysFor(EquipmentType t) =>
        EquipmentAttributeCatalog.attributesFor(
          t,
        ).map((d) => d.key).where((k) => !shared.contains(k)).toList();
    EquipmentAttributeDef def(String key) =>
        EquipmentAttributeCatalog.defFor(key)!;

    test('each part carries the fields that tell it apart', () {
      expect(keysFor(EquipmentType.lens), ['lens_type', 'focal_length_mm']);
      expect(keysFor(EquipmentType.port), ['port_type', 'depth_rating_m']);
      expect(keysFor(EquipmentType.trayHandle), ['tray_style']);
      expect(keysFor(EquipmentType.armClamp), ['arm_length_m']);
      expect(keysFor(EquipmentType.videoLight), [
        'lumens',
        'beam_type',
        'depth_rating_m',
      ]);
      expect(keysFor(EquipmentType.floatArm), ['lift_capacity_kg']);
      expect(keysFor(EquipmentType.strobe), [
        'depth_rating_m',
        'guide_number_m',
      ]);
    });

    test('choices and dimensions', () {
      expect(def('lens_type').kind, AttributeKind.choice);
      expect(def('lens_type').choiceKeys, [
        'camera_lens',
        'wet_lens',
        'diopter',
      ]);
      // Focal length is quoted in millimetres in every unit system, so it is
      // a plain number rather than a converted length.
      expect(def('focal_length_mm').kind, AttributeKind.number);
      expect(def('focal_length_mm').dimension, AttributeDimension.none);
      expect(def('port_type').choiceKeys, ['dome', 'flat', 'macro']);
      expect(def('tray_style').choiceKeys, [
        'single_handle',
        'double_handle',
        'pistol_grip',
      ]);
      expect(def('arm_length_m').dimension, AttributeDimension.shortLengthM);
      // A guide number is a distance, quoted in metres or feet, so it
      // follows the diver's length unit.
      expect(def('guide_number_m').kind, AttributeKind.number);
      expect(def('guide_number_m').dimension, AttributeDimension.lengthM);
    });

    test('the video light shares the dive light\'s definitions', () {
      List<EquipmentAttributeDef> specific(EquipmentType t) =>
          EquipmentAttributeCatalog.attributesFor(
            t,
          ).where((d) => d.key == 'lumens' || d.key == 'beam_type').toList();
      expect(specific(EquipmentType.videoLight), specific(EquipmentType.light));
    });

    test('every field and option has a localized label', () {
      for (final type in [...added.keys, EquipmentType.strobe]) {
        for (final d in EquipmentAttributeCatalog.attributesFor(type)) {
          expect(
            attributeLabel(l10n, d.key),
            isNot(d.key),
            reason: 'missing attrLabel_${d.key}',
          );
          for (final option in d.choiceKeys) {
            expect(
              attributeChoiceLabel(l10n, d.key, option),
              isNot(option),
              reason: 'missing attrChoice_${d.key}_$option',
            );
          }
        }
      }
    });
  });

  test('a video light counts battery cycles like a dive light', () {
    expect(kBatteryPoweredTypes, contains(EquipmentType.videoLight));
  });

  test('a video light shows the battery installed in it', () {
    // The edit page offers a battery these hosts, and the detail page shows
    // the Children card for the same set, so the battery is never hidden.
    expect(childHostTypes, contains(EquipmentType.videoLight));
  });

  test('check-in tags: a video light is a light, a port can flood', () {
    expect(
      observationTagsFor(EquipmentType.videoLight),
      observationTagsFor(EquipmentType.light),
    );
    expect(
      observationTagsFor(EquipmentType.port),
      contains(ObservationTag.flooded),
    );
  });

  test('no camera part moves the lead prediction', () {
    // A photo rig is hand-held and trimmed near neutral by its floats, so a
    // part contributes nothing to the diver's lead unless the diver enters
    // a buoyancy of their own.
    for (final type in added.keys) {
      final feature = GearFeature.fromEquipment(
        id: 'p',
        type: type,
        name: 'Camera part',
      );
      expect(feature.priorKg, 0.0, reason: type.name);
    }
  });

  test('the diver figure draws the video light on the camera arm', () {
    expect(FigurePlacement.forType(EquipmentType.videoLight).zones, [
      FigureZone.cameraArm,
    ]);
    for (final type in [
      EquipmentType.lens,
      EquipmentType.port,
      EquipmentType.trayHandle,
      EquipmentType.armClamp,
      EquipmentType.floatArm,
    ]) {
      expect(FigurePlacement.trayTypes, contains(type), reason: type.name);
    }
  });
}
