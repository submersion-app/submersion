import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
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

  test('the rig accessories follow the harness (#1877)', () {
    // Cam bands and pockets were being typed BCD, burying the real BCDs
    // under them in a type filter; they sit with the rest of the BCD family.
    expect(indexOf(EquipmentType.tankBand), indexOf(EquipmentType.harness) + 1);
    expect(
      indexOf(EquipmentType.weightPocket),
      indexOf(EquipmentType.harness) + 2,
    );
    expect(
      indexOf(EquipmentType.gearPocket),
      indexOf(EquipmentType.harness) + 3,
    );
  });

  test('the rig accessories carry a label, their own icon and .name', () {
    const added = {
      EquipmentType.tankBand: ('Tank Band', 'tankBand'),
      EquipmentType.weightPocket: ('Weight Pocket', 'weightPocket'),
      EquipmentType.gearPocket: ('Gear Pocket', 'gearPocket'),
    };
    final generic = equipmentTypeIcon(EquipmentType.other);
    for (final entry in added.entries) {
      final (label, name) = entry.value;
      expect(entry.key.localizedName(l10n), label, reason: name);
      expect(entry.key.displayName, label, reason: name);
      // `.name` is what `equipment.type` persists, so it is part of the
      // storage contract, not a detail.
      expect(entry.key.name, name);
      expect(equipmentTypeIcon(entry.key), isNot(generic), reason: name);
    }
  });

  test('the rig accessories carry the fields that tell them apart', () {
    // Type-specific keys only: every type also carries the universal and
    // purchase fields.
    final shared = {
      ...EquipmentAttributeCatalog.universal,
      ...EquipmentAttributeCatalog.purchase,
    }.map((d) => d.key).toSet();
    List<String> keysFor(EquipmentType t) =>
        EquipmentAttributeCatalog.attributesFor(
          t,
        ).map((d) => d.key).where((k) => !shared.contains(k)).toList();
    expect(keysFor(EquipmentType.tankBand), ['band_style']);
    expect(keysFor(EquipmentType.weightPocket), [
      'weight_style',
      'pocket_capacity_kg',
    ]);
    expect(keysFor(EquipmentType.gearPocket), ['pocket_mount']);

    final band = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.tankBand,
    ).first;
    expect(band.kind, AttributeKind.choice);
    expect(band.choiceKeys, ['cam_strap', 'stainless_band']);

    // The pocket reuses the Weights type's style key and wording, offering
    // only the placements a pocket can have: an ankle weight has no pocket.
    final pocketStyle = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.weightPocket,
    ).first;
    expect(pocketStyle.kind, AttributeKind.choice);
    expect(pocketStyle.choiceKeys, ['belt', 'integrated', 'trim']);
    // Lookups by key alone (the active-filter label orders its options by
    // it) must still see the Weights type's full list, ankle included; the
    // pocket's list is an in-order subset of it, so either reading ranks
    // the options the same way.
    final byKey = EquipmentAttributeCatalog.defFor('weight_style')!;
    expect(byKey.choiceKeys, ['belt', 'integrated', 'trim', 'ankle']);
    expect(
      byKey.choiceKeys.where(pocketStyle.choiceKeys.contains).toList(),
      pocketStyle.choiceKeys,
    );

    final capacity = EquipmentAttributeCatalog.defFor('pocket_capacity_kg')!;
    expect(capacity.kind, AttributeKind.number);
    expect(capacity.dimension, AttributeDimension.massKg);

    final mount = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.gearPocket,
    ).first;
    expect(mount.kind, AttributeKind.choice);
    expect(mount.choiceKeys, ['harness', 'waist_belt', 'thigh']);
  });

  test('every rig accessory field and option has a localized label', () {
    const types = [
      EquipmentType.tankBand,
      EquipmentType.weightPocket,
      EquipmentType.gearPocket,
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
    expect(
      keysFor(EquipmentType.hose),
      containsAll(['hose_type', 'hose_length_m']),
    );
    expect(keysFor(EquipmentType.backplate), contains('plate_material'));
    expect(keysFor(EquipmentType.wing), contains('lift_capacity_kg'));
    expect(keysFor(EquipmentType.harness), contains('size'));
    expect(keysFor(EquipmentType.housing), contains('depth_rating_m'));
    expect(keysFor(EquipmentType.strobe), contains('depth_rating_m'));
    final hose = EquipmentAttributeCatalog.defFor('hose_length_m')!;
    expect(hose.dimension, AttributeDimension.shortLengthM);
  });
}
