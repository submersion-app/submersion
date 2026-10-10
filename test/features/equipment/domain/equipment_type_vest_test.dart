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
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/domain/services/gear_feature_mapper.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Vest type (issue #3108): a neoprene vest worn with a wetsuit, the
/// hooded ice vest over it or a core warmer under it. It is a layer, not a
/// suit, so a dive logged with a full suit and a vest still has one suit.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  test('carries a label, a hooded-vest glyph and a persisted .name', () {
    expect(EquipmentType.vest.displayName, 'Vest');
    expect(EquipmentType.vest.localizedName(en), 'Vest');
    // `.name` is what `equipment.type` persists, so it is part of the
    // storage contract, not a detail.
    expect(EquipmentType.vest.name, 'vest');
    expect(equipmentTypeIcon(EquipmentType.vest), SubmersionIcons.vest);
  });

  test('has a label in every locale, never the English fallback', () {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final l10n = lookupAppLocalizations(locale);
      expect(
        EquipmentType.vest.localizedName(l10n),
        isNot('Vest'),
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

    test('a vest records size, thickness, hood, layer and closure', () {
      final keys = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.vest,
      ).map((d) => d.key).where((k) => !shared.contains(k)).toList();
      expect(keys, [
        EquipmentAttrKeys.size,
        EquipmentAttrKeys.thicknessMm,
        EquipmentAttrKeys.hooded,
        'vest_layer',
        'vest_closure',
      ]);
    });

    test('the hood is a switch and the thickness a suit thickness', () {
      expect(
        EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.hooded)!.kind,
        AttributeKind.flag,
      );
      expect(
        EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.thicknessMm)!.kind,
        AttributeKind.thickness,
      );
    });

    test('the layer and closure are choices', () {
      final layer = EquipmentAttributeCatalog.defFor('vest_layer')!;
      expect(layer.kind, AttributeKind.choice);
      expect(layer.choiceKeys, ['over_suit', 'under_suit']);
      final closure = EquipmentAttributeCatalog.defFor('vest_closure')!;
      expect(closure.kind, AttributeKind.choice);
      expect(closure.choiceKeys, ['front_zip', 'side_zip', 'pullover']);
    });

    test('every field and option has a label in every locale', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final def in EquipmentAttributeCatalog.attributesFor(
          EquipmentType.vest,
        )) {
          expect(
            attributeLabel(l10n, def.key),
            isNot(def.key),
            reason: '${locale.languageCode}: attrLabel_${def.key}',
          );
          for (final option in def.choiceKeys) {
            expect(
              attributeChoiceLabel(l10n, def.key, option),
              isNot(option),
              reason: '${locale.languageCode}: attrChoice_${def.key}_$option',
            );
          }
        }
      }
    });
  });

  group('a vest is a layer, not a suit', () {
    test('the suit thickness filter does not reach it', () {
      expect(
        EquipmentAttrCondition.suitTypes,
        isNot(contains(EquipmentType.vest)),
      );
      final vest = EquipmentItem(
        id: 'v',
        name: '7mm ice vest',
        type: EquipmentType.vest,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'v',
            key: EquipmentAttrKeys.thicknessMm,
            valueText: '7',
            valueNum: 7,
          ),
        ],
      );
      expect(EquipmentAttrCondition.suitThickness(min: 5).matches(vest), false);
    });

    test('it sits beside the suits in every body order', () {
      for (final table in [kHeadToToeTypeOrder, kDressingTypeOrder]) {
        expect(
          table.indexOf(EquipmentType.vest),
          table.indexOf(EquipmentType.drysuit) + 1,
        );
      }
      // In the exposure family, after the suits and ahead of the hood.
      expect(
        kCanonicalTypeOrder.indexOf(EquipmentType.vest),
        kCanonicalTypeOrder.indexOf(EquipmentType.hood) - 1,
      );
    });

    test('it takes the tear and seam observations of a wetsuit', () {
      expect(
        observationTagsFor(EquipmentType.vest),
        observationTagsFor(EquipmentType.wetsuit),
      );
    });
  });

  group('figure', () {
    test('draws over the torso without taking the suit from a wetsuit', () {
      final model = composeFigure(const [
        FigureItemInput(id: 'w', type: EquipmentType.wetsuit, name: 'Suit'),
        FigureItemInput(id: 'v', type: EquipmentType.vest, name: 'Ice vest'),
      ]);
      final suit = model.placed.singleWhere((p) => p.item.id == 'w');
      final vest = model.placed.singleWhere((p) => p.item.id == 'v');
      expect(suit.zone, FigureZone.suit);
      expect(vest.zone, FigureZone.underlayer);
      expect(vest.pieceIds, ['vest_front', 'vest_back']);
      expect(model.tray, isEmpty);
    });

    test('with both underlayer slots taken it still finds the body', () {
      final model = composeFigure(const [
        FigureItemInput(id: 'd', type: EquipmentType.drysuit, name: 'Dry'),
        FigureItemInput(id: 'u', type: EquipmentType.undersuit, name: 'U'),
        FigureItemInput(id: 'b', type: EquipmentType.baselayer, name: 'B'),
        FigureItemInput(id: 'v', type: EquipmentType.vest, name: 'Vest'),
      ]);
      expect(model.tray, isEmpty);
      final vest = model.placed.singleWhere((p) => p.item.id == 'v');
      expect(vest.zone, FigureZone.torsoFront);
      expect(vest.pieceIds, ['vest_front', 'vest_back']);
    });

    test('a hooded vest draws its hood in the vest colour', () {
      final spec = FigurePlacement.forType(
        EquipmentType.vest,
        attributes: const {EquipmentAttrKeys.hooded: 'true'},
      );
      expect(spec.piecesFor(FigureZone.underlayer), [
        'vest_front',
        'vest_back',
        'hood_front',
        'hood_back',
      ]);
    });

    test('the hood switch reaches the figure from a stored item', () {
      EquipmentItem vest(double on) => EquipmentItem(
        id: 'v',
        name: 'Vest',
        type: EquipmentType.vest,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'v',
            key: EquipmentAttrKeys.hooded,
            valueNum: on,
          ),
        ],
      );
      expect(figureAttributesOf(vest(1))[EquipmentAttrKeys.hooded], 'true');
      expect(figureAttributesOf(vest(0))[EquipmentAttrKeys.hooded], 'false');
    });
  });

  group('buoyancy', () {
    GearFeature vest({double? mm, bool? hooded}) => GearFeature.fromEquipment(
      id: 'v',
      type: EquipmentType.vest,
      name: 'Vest',
      traits: GearBuoyancyTraits(primaryThicknessMm: mm, hooded: hooded),
    );

    test('a torso-only garment lifts about a third of a full suit', () {
      expect(vest(mm: 7).priorKg, closeTo(2.45, 1e-9));
    });

    test('the hood adds what a separate hood of that thickness would', () {
      expect(
        vest(mm: 7, hooded: true).priorKg - vest(mm: 7).priorKg,
        closeTo(0.7, 1e-9),
      );
    });

    test('without a thickness it falls back to its own default', () {
      expect(vest().priorKg, 1.0);
      expect(vest().dryMassKg, 0.8);
    });

    test('a thickness stated only in the name still counts', () {
      // Imports leave a vest's thickness in its name ("7mm ice vest"), as
      // they did for wetsuits before the thickness attribute existed.
      final named = GearFeature.fromEquipment(
        id: 'v',
        type: EquipmentType.vest,
        name: '7mm ice vest',
      );
      expect(named.priorKg, closeTo(2.45, 1e-9));
      final hooded = GearFeature.fromEquipment(
        id: 'v',
        type: EquipmentType.vest,
        name: '7mm ice vest',
        traits: const GearBuoyancyTraits(hooded: true),
      );
      expect(hooded.priorKg, closeTo(3.15, 1e-9));
    });

    test('an implausible thickness is clamped', () {
      expect(vest(mm: 15, hooded: true).priorKg, 5.0);
    });

    test('the mapper reads the hood switch from the stored item', () {
      final feature = gearFeatureFromEquipment(
        EquipmentItem(
          id: 'v',
          name: 'Ice vest',
          type: EquipmentType.vest,
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: 'v',
              key: EquipmentAttrKeys.thicknessMm,
              valueText: '7',
              valueNum: 7,
            ),
            EquipmentAttribute.curated(
              equipmentId: 'v',
              key: EquipmentAttrKeys.hooded,
              valueNum: 1,
            ),
          ],
        ),
      )!;
      expect(feature.priorKg, closeTo(3.15, 1e-9));
    });
  });
}
