import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Bag type (issue #2952): gear bags, roller bags, mesh and dry bags.
/// A bag carries gear rather than being worn, which decides where it sits
/// in every ordering and what it adds to a dive.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  test('carries a label, a luggage icon and a persisted .name', () {
    expect(EquipmentType.bag.displayName, 'Bag');
    expect(EquipmentType.bag.localizedName(en), 'Bag');
    // `.name` is what `equipment.type` persists, so it is part of the
    // storage contract, not a detail.
    expect(EquipmentType.bag.name, 'bag');
    expect(equipmentTypeIcon(EquipmentType.bag), Icons.luggage);
  });

  test('names one item in French, like every other type label', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(EquipmentType.bag.localizedName(fr), 'Sac');
  });

  test('has a label in every locale, never the English fallback', () {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final l10n = lookupAppLocalizations(locale);
      expect(
        EquipmentType.bag.localizedName(l10n),
        isNot('Bag'),
        reason: locale.languageCode,
      );
    }
  });

  group('attributes', () {
    final shared = {
      ...EquipmentAttributeCatalog.universal,
      ...EquipmentAttributeCatalog.purchase,
      ...EquipmentAttributeCatalog.appearance,
    }.map((d) => d.key).toSet();

    test('a bag records its style and its capacity', () {
      final keys = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.bag,
      ).map((d) => d.key).where((k) => !shared.contains(k)).toList();
      expect(keys, ['bag_style', 'capacity_l']);
    });

    test('the style is a choice that excludes lift bags', () {
      final style = EquipmentAttributeCatalog.defFor('bag_style')!;
      expect(style.kind, AttributeKind.choice);
      expect(style.choiceKeys, [
        'duffel',
        'roller',
        'backpack',
        'mesh',
        'dry_bag',
        'regulator_bag',
        'catch_bag',
      ]);
    });

    test('the capacity is a volume, so it follows the diver units', () {
      final capacity = EquipmentAttributeCatalog.defFor('capacity_l')!;
      expect(capacity.kind, AttributeKind.number);
      expect(capacity.dimension, AttributeDimension.volumeL);
    });

    test('every field and option has a localized label', () {
      for (final def in EquipmentAttributeCatalog.attributesFor(
        EquipmentType.bag,
      )) {
        expect(
          attributeLabel(en, def.key),
          isNot(def.key),
          reason: 'missing attrLabel_${def.key}',
        );
        for (final option in def.choiceKeys) {
          expect(
            attributeChoiceLabel(en, def.key, option),
            isNot(option),
            reason: 'missing attrChoice_${def.key}_$option',
          );
        }
      }
    });
  });

  group('a bag is carried, not worn', () {
    test('it never draws on the diver figure, only in the tray', () {
      final spec = FigurePlacement.forType(EquipmentType.bag);
      expect(spec.zones, isEmpty);
      expect(spec.isTray, isTrue);
      expect(FigurePlacement.trayTypes, contains(EquipmentType.bag));
    });

    test('it adds no mass to a dive unless the diver states one', () {
      GearFeature bag({double? weightKg}) => GearFeature.fromEquipment(
        id: 'gear-1',
        type: EquipmentType.bag,
        name: 'Roller bag',
        weightKg: weightKg,
      );
      // A travel bag in a dive's gear list must not move the weighting
      // estimate by the 0.5 kg fallthrough.
      expect(bag().dryMassKg, 0.0);
      expect(bag().priorKg, 0.0);
      expect(bag(weightKg: 0.4).dryMassKg, 0.4);
    });

    test('it follows the worn gear in the body orders', () {
      // After every worn item, just ahead of the consumable child parts
      // and the catch-all.
      for (final table in [kHeadToToeTypeOrder, kDressingTypeOrder]) {
        expect(
          table.indexOf(EquipmentType.bag),
          table.indexOf(EquipmentType.o2Cell) - 1,
        );
      }
    });

    test('it opens a transport family after the accessories', () {
      expect(
        kCanonicalTypeOrder.indexOf(EquipmentType.bag),
        kCanonicalTypeOrder.indexOf(EquipmentType.tool) + 1,
      );
    });
  });
}
