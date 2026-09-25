import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// The placement table is the whole "where does it go" knowledge of the
/// figure, so every type has to answer, and the variants have to move gear
/// the way the attribute says.
void main() {
  test('every type either has candidate zones or is a tray type', () {
    for (final type in EquipmentType.values) {
      final spec = FigurePlacement.forType(type);
      if (FigurePlacement.trayTypes.contains(type)) {
        expect(spec.isTray, isTrue, reason: type.name);
      } else {
        expect(spec.zones, isNotEmpty, reason: type.name);
        for (final zone in spec.zones) {
          expect(
            spec.piecesFor(zone),
            isNotEmpty,
            reason: '${type.name} has no artwork for ${zone.name}',
          );
        }
      }
    }
  });

  test('a tank goes on the back unless the rig is sidemount', () {
    expect(
      FigurePlacement.forType(EquipmentType.tank).zones.first,
      FigureZone.backTank,
    );
    final sidemount = FigurePlacement.forType(
      EquipmentType.tank,
      context: const FigureContext(sidemountRig: true),
    );
    expect(sidemount.zones.take(2), [
      FigureZone.sidemountLeft,
      FigureZone.sidemountRight,
    ]);
    expect(sidemount.zones, isNot(contains(FigureZone.backTank)));
    // Dive tank roles can still land a tank on the back in a sidemount rig,
    // so the artwork for every tank zone is always present.
    expect(sidemount.piecesFor(FigureZone.backTank), ['tank_single_back']);
  });

  test('a steel tank is drawn darker than an aluminium one', () {
    final aluminium = FigurePlacement.forType(EquipmentType.tank).defaultColor;
    final steel = FigurePlacement.forType(
      EquipmentType.tank,
      attributes: {EquipmentAttrKeys.tankMaterial: 'steel'},
    ).defaultColor;
    expect(steel, FigureColors.steel);
    expect(aluminium, FigureColors.aluminium);
  });

  test('a BCD is worn on the back and its style picks its pieces', () {
    expect(FigurePlacement.forType(EquipmentType.bcd).zones, [FigureZone.wing]);
    expect(
      FigurePlacement.forType(EquipmentType.bcd).piecesFor(FigureZone.wing),
      ['bcd_jacket_front', 'bcd_jacket_back'],
    );
    expect(
      FigurePlacement.forType(
        EquipmentType.bcd,
        attributes: {EquipmentAttrKeys.bcdStyle: 'wing'},
      ).piecesFor(FigureZone.wing),
      ['bcd_harness_front', 'bcd_wing_back'],
    );
    expect(
      FigurePlacement.forType(
        EquipmentType.bcd,
        attributes: {EquipmentAttrKeys.bcdStyle: 'sidemount'},
      ).piecesFor(FigureZone.wing),
      ['bcd_sidemount_front', 'bcd_sidemount_back'],
    );
    // A separate harness item is still worn and labelled on the front.
    expect(FigurePlacement.forType(EquipmentType.harness).zones, [
      FigureZone.torsoFront,
    ]);
  });

  test('an unknown attribute value falls back to the default variant', () {
    final spec = FigurePlacement.forType(
      EquipmentType.bcd,
      attributes: {EquipmentAttrKeys.bcdStyle: 'unknown'},
    );
    expect(spec.piecesFor(FigureZone.wing), [
      'bcd_jacket_front',
      'bcd_jacket_back',
    ]);
    final computer = FigurePlacement.forType(
      EquipmentType.computer,
      attributes: {'mount': 'ankle'},
    );
    expect(computer.zones, [FigureZone.wristLeft, FigureZone.wristRight]);
  });

  test('a console computer, a HUD, and integrated weights move zones', () {
    expect(
      FigurePlacement.forType(
        EquipmentType.computer,
        attributes: {'mount': 'console'},
      ).zones,
      [FigureZone.console],
    );
    expect(
      FigurePlacement.forType(
        EquipmentType.computer,
        attributes: {'mount': 'hud'},
      ).zones,
      [FigureZone.hud],
    );
    expect(
      FigurePlacement.forType(
        EquipmentType.weights,
        attributes: {EquipmentAttrKeys.weightStyle: 'integrated'},
      ).zones,
      [FigureZone.hipLeft, FigureZone.hipRight],
    );
    expect(
      FigurePlacement.forType(
        EquipmentType.weights,
        attributes: {EquipmentAttrKeys.weightStyle: 'trim'},
      ).zones,
      [FigureZone.trimLeft, FigureZone.trimRight],
    );
    expect(
      FigurePlacement.forType(
        EquipmentType.gearPocket,
        attributes: {'pocket_mount': 'thigh'},
      ).zones,
      [FigureZone.thighLeft, FigureZone.thighRight],
    );
  });

  test('a back-mounted rebreather takes the whole back tank zone', () {
    final spec = FigurePlacement.forType(EquipmentType.rebreather);
    expect(spec.zones, [FigureZone.backTank]);
    expect(spec.occupies, FigureZone.backTank.capacity);
    expect(
      FigurePlacement.forType(
        EquipmentType.rebreather,
        attributes: {'mount_configuration': 'chest'},
      ).zones,
      [FigureZone.chest],
    );
  });

  test('only a sidemount BCD or rebreather makes a sidemount rig', () {
    expect(
      FigurePlacement.contributesSidemountRig(EquipmentType.bcd, {
        EquipmentAttrKeys.bcdStyle: 'sidemount',
      }),
      isTrue,
    );
    expect(
      FigurePlacement.contributesSidemountRig(EquipmentType.rebreather, {
        'mount_configuration': 'sidemount',
      }),
      isTrue,
    );
    expect(
      FigurePlacement.contributesSidemountRig(EquipmentType.bcd, {}),
      isFalse,
    );
    expect(
      FigurePlacement.contributesSidemountRig(EquipmentType.harness, {}),
      isFalse,
    );
  });

  test('child types are tray types when they arrive top level', () {
    for (final type in FigurePlacement.childTypes) {
      expect(FigurePlacement.trayTypes, contains(type));
    }
  });

  test('fins and boots are drawn on both views', () {
    expect(
      FigurePlacement.forType(EquipmentType.fins).piecesFor(FigureZone.fins),
      ['fins_front', 'fins_back'],
    );
    expect(
      FigurePlacement.forType(EquipmentType.boots).piecesFor(FigureZone.feet),
      ['boots_front', 'boots_back'],
    );
  });
}
