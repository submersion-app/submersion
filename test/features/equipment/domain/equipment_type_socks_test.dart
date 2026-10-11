import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/constants/observation_tag_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/gear_feature_mapper.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Socks type (issue #2900): neoprene wet socks worn in open-heel fins
/// or under boots, and thermal socks worn inside a drysuit's feet. One type
/// told apart by sock_type, the way gloves are told apart by glove_type.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  test('carries a label, a drawn icon and a persisted .name', () {
    expect(EquipmentType.socks.displayName, 'Socks');
    expect(EquipmentType.socks.localizedName(en), 'Socks');
    // `.name` is what `equipment.type` persists, so it is part of the
    // storage contract, not a detail.
    expect(EquipmentType.socks.name, 'socks');
    expect(equipmentTypeIcon(EquipmentType.socks), SubmersionIcons.socks);
  });

  test('has a label in every locale, never the English fallback', () {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final l10n = lookupAppLocalizations(locale);
      expect(
        EquipmentType.socks.localizedName(l10n),
        isNot('Socks'),
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

    test('socks record size, thickness, kind and fill', () {
      final keys = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.socks,
      ).map((d) => d.key).where((k) => !shared.contains(k)).toList();
      expect(keys, [
        EquipmentAttrKeys.size,
        EquipmentAttrKeys.thicknessMm,
        EquipmentAttrKeys.sockType,
        EquipmentAttrKeys.fillMaterial,
      ]);
    });

    test('the kind is a choice between wet and drysuit socks', () {
      final kind = EquipmentAttributeCatalog.defFor(
        EquipmentAttrKeys.sockType,
      )!;
      expect(kind.kind, AttributeKind.choice);
      expect(kind.choiceKeys, ['neoprene', 'drysuit']);
    });

    test('every field and option has a localized label', () {
      for (final def in EquipmentAttributeCatalog.attributesFor(
        EquipmentType.socks,
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

  group('buoyancy', () {
    GearFeature socks({GearBuoyancyTraits? traits, double? weightKg}) =>
        GearFeature.fromEquipment(
          id: 'gear-1',
          type: EquipmentType.socks,
          name: 'Socks',
          weightKg: weightKg,
          traits: traits,
        );

    test('neoprene socks float by their thickness, half a boot', () {
      final f = socks(
        traits: const GearBuoyancyTraits(
          primaryThicknessMm: 3,
          sockType: 'neoprene',
        ),
      );
      expect(f.priorKg, closeTo(0.18, 1e-9));
    });

    test('a thickness alone reads as neoprene', () {
      final f = socks(traits: const GearBuoyancyTraits(primaryThicknessMm: 5));
      expect(f.priorKg, closeTo(0.30, 1e-9));
    });

    test('a mistyped thickness stays bounded', () {
      // Thickness is clamped to 15 mm before the coefficient applies, so a
      // stray 30 lands on the same 0.9 kg ceiling as a 15.
      final f = socks(
        traits: const GearBuoyancyTraits(
          primaryThicknessMm: 30,
          sockType: 'neoprene',
        ),
      );
      expect(f.priorKg, closeTo(0.9, 1e-9));
    });

    test('drysuit socks barely move the lead', () {
      final f = socks(
        traits: const GearBuoyancyTraits(
          primaryThicknessMm: 5,
          sockType: 'drysuit',
        ),
      );
      expect(f.priorKg, 0.05);
    });

    test('the stored sock_type reaches the prior', () {
      // Through the attribute store, as a dive's gear list does it: without
      // the mapper reading sock_type, a 5 mm drysuit sock would weigh in as
      // neoprene at 0.3 kg.
      EquipmentAttribute attr(String key, {String? text, double? num}) =>
          EquipmentAttribute(
            id: 'a-$key',
            equipmentId: 's1',
            key: key,
            valueText: text,
            valueNum: num,
          );
      final feature = gearFeatureFromEquipment(
        EquipmentItem(
          id: 's1',
          name: 'Drysuit socks',
          type: EquipmentType.socks,
          attributes: [
            attr(EquipmentAttrKeys.thicknessMm, text: '5', num: 5),
            attr(EquipmentAttrKeys.sockType, text: 'drysuit'),
          ],
        ),
      )!;
      expect(feature.priorKg, 0.05);
    });

    test('unrated socks take the type default and a light dry mass', () {
      final f = socks();
      expect(f.priorKg, 0.15);
      expect(f.dryMassKg, 0.1);
    });
  });

  group('orders', () {
    test('head to toe runs gloves, socks, boots', () {
      final i = kHeadToToeTypeOrder.indexOf(EquipmentType.socks);
      expect(kHeadToToeTypeOrder[i - 1], EquipmentType.gloves);
      expect(kHeadToToeTypeOrder[i + 1], EquipmentType.boots);
    });

    test('socks go on with the under-layers, before any suit', () {
      final i = kDressingTypeOrder.indexOf(EquipmentType.socks);
      expect(kDressingTypeOrder[i - 1], EquipmentType.undersuit);
      expect(kDressingTypeOrder[i + 1], EquipmentType.wetsuit);
    });

    test('canonically socks follow boots, which claim the feet first', () {
      final i = kCanonicalTypeOrder.indexOf(EquipmentType.socks);
      expect(kCanonicalTypeOrder[i - 1], EquipmentType.boots);
    });
  });

  test('socks share the exposure garments observation tags', () {
    expect(
      observationTagsFor(EquipmentType.socks),
      observationTagsFor(EquipmentType.boots),
    );
  });

  group('diver figure', () {
    test('socks draw on the feet', () {
      final spec = FigurePlacement.forType(EquipmentType.socks);
      expect(spec.zones, [FigureZone.feet]);
      expect(spec.piecesFor(FigureZone.feet), ['socks_front', 'socks_back']);
    });

    test('bare-footed in open-heel fins, socks show on the feet', () {
      final model = composeFigure(const [
        FigureItemInput(id: 's', type: EquipmentType.socks, name: 'Socks'),
        FigureItemInput(id: 'f', type: EquipmentType.fins, name: 'Fins'),
      ]);
      final socks = model.placed.singleWhere((p) => p.item.id == 's');
      expect(socks.zone, FigureZone.feet);
      expect(model.tray, isEmpty);
    });

    test('with boots in the set, socks drop to the tray', () {
      // Listed first so the result cannot come from input order.
      final model = composeFigure(const [
        FigureItemInput(id: 's', type: EquipmentType.socks, name: 'Socks'),
        FigureItemInput(id: 'b', type: EquipmentType.boots, name: 'Boots'),
      ]);
      final boots = model.placed.singleWhere((p) => p.item.id == 'b');
      expect(boots.zone, FigureZone.feet);
      expect(model.tray.map((p) => p.item.id), ['s']);
    });
  });
}
