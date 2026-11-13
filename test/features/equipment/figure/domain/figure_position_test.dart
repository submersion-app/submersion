import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_position.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// Where a diver can put an item on the figure (issue #4493): only spots
/// that draw the item differently, so the picker never offers a choice that
/// changes nothing.
void main() {
  group('pickableFigureZones', () {
    test('a cylinder offers the back, both sidemount sides and both stage '
        'sides', () {
      expect(
        pickableFigureZones(EquipmentType.tank, const {}),
        unorderedEquals([
          FigureZone.backTank,
          FigureZone.sidemountLeft,
          FigureZone.sidemountRight,
          FigureZone.stageLeft,
          FigureZone.stageRight,
        ]),
      );
    });

    test('a light offers its hand and both chest clips', () {
      expect(
        pickableFigureZones(EquipmentType.light, const {}),
        unorderedEquals([
          FigureZone.handLeft,
          FigureZone.chestClipLeft,
          FigureZone.chestClipRight,
        ]),
      );
    });

    test('a wrist computer offers both wrists; a console one offers none', () {
      expect(
        pickableFigureZones(EquipmentType.computer, const {}),
        unorderedEquals([FigureZone.wristLeft, FigureZone.wristRight]),
      );
      expect(
        pickableFigureZones(EquipmentType.computer, const {'mount': 'console'}),
        isEmpty,
      );
    });

    test('a vest offers nothing: every zone draws it the same way', () {
      expect(pickableFigureZones(EquipmentType.vest, const {}), isEmpty);
      expect(pickableFigureZones(EquipmentType.rashGuard, const {}), isEmpty);
    });

    test('a type with one spot or none offers nothing', () {
      expect(pickableFigureZones(EquipmentType.mask, const {}), isEmpty);
      expect(pickableFigureZones(EquipmentType.hose, const {}), isEmpty);
    });

    test('every pickable zone has a stored key and the catalog offers it', () {
      final def = EquipmentAttributeCatalog.defFor(
        EquipmentAttrKeys.figurePosition,
      )!;
      for (final type in EquipmentType.values) {
        for (final attributes in FigurePlacement.variantAttributeSets) {
          for (final zone in pickableFigureZones(type, attributes)) {
            final key = figurePositionKeys[zone];
            expect(key, isNotNull, reason: '$type $zone has no key');
            expect(def.choiceKeys, contains(key));
          }
        }
      }
      expect(def.choiceKeys.toSet(), figurePositionKeys.values.toSet());
    });
  });

  group('figurePositionZone', () {
    test('reads a stored key back to its zone', () {
      expect(figurePositionZone('sidemount_left'), FigureZone.sidemountLeft);
      expect(figurePositionZone('hand_left'), FigureZone.handLeft);
    });

    test('an unknown or missing key is no position', () {
      expect(figurePositionZone(null), isNull);
      expect(figurePositionZone('ceiling'), isNull);
    });
  });

  group('wornAsZones', () {
    test('maps each choice to its zones, the named side first', () {
      expect(wornAsZones('back'), [FigureZone.backTank]);
      expect(wornAsZones('sidemount_left'), [
        FigureZone.sidemountLeft,
        FigureZone.sidemountRight,
      ]);
      expect(wornAsZones('sidemount_right'), [
        FigureZone.sidemountRight,
        FigureZone.sidemountLeft,
      ]);
      expect(wornAsZones('stage'), [
        FigureZone.stageLeft,
        FigureZone.stageRight,
      ]);
      expect(wornAsZones(null), isEmpty);
      expect(wornAsZones('chest'), isEmpty);
    });

    test('the catalog offers exactly the choices it maps', () {
      final def = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.wornAs)!;
      expect(def.kind, AttributeKind.choice);
      for (final key in def.choiceKeys) {
        expect(wornAsZones(key), isNotEmpty, reason: key);
      }
      expect(
        EquipmentAttributeCatalog.attributesFor(
          EquipmentType.tank,
        ).map((d) => d.key),
        contains(EquipmentAttrKeys.wornAs),
      );
    });
  });
}
