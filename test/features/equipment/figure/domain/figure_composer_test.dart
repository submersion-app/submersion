import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// The composer decides where each item sits and what number it carries.
/// Placement walks the canonical type order so an outer suit always wins
/// the suit zone; numbering follows the caller's order so the digits run
/// down the legend (spec 4.3).
void main() {
  FigureItemInput item(
    String id,
    EquipmentType type, {
    Map<String, String?> attributes = const {},
    bool isChild = false,
    TankRole? tankRole,
  }) => FigureItemInput(
    id: id,
    type: type,
    name: id,
    attributes: attributes,
    isChild: isChild,
    tankRole: tankRole,
  );

  test('numbers follow input order while placement follows type order', () {
    // A second stage listed before the regulator is numbered first, but the
    // regulator (earlier in the canonical order) is placed first and takes
    // the mouth, leaving the octo slot to the second stage.
    final model = composeFigure([
      item('second', EquipmentType.secondStage),
      item('reg', EquipmentType.regulator),
    ]);
    expect(model.byId('second')!.number, 1);
    expect(model.byId('reg')!.number, 2);
    expect(model.byId('reg')!.zone, FigureZone.mouth);
    expect(model.byId('second')!.zone, FigureZone.octo);
  });

  test('a rash guard leaves the suit zone to a wetsuit', () {
    final model = composeFigure([
      item('rash', EquipmentType.rashGuard),
      item('wet', EquipmentType.wetsuit),
    ]);
    expect(model.byId('wet')!.zone, FigureZone.suit);
    expect(model.byId('rash')!.zone, FigureZone.underlayer);
    // Alone, it still has a place.
    expect(
      composeFigure([item('rash', EquipmentType.rashGuard)]).byId('rash')!.zone,
      FigureZone.underlayer,
    );
  });

  test('a second item of a type takes the next candidate zone', () {
    final model = composeFigure([
      item('c1', EquipmentType.computer),
      item('c2', EquipmentType.computer),
      item('c3', EquipmentType.computer),
    ]);
    expect(model.byId('c1')!.zone, FigureZone.wristLeft);
    expect(model.byId('c2')!.zone, FigureZone.wristRight);
    expect(model.byId('c3')!.zone, isNull);
    expect(model.tray.map((p) => p.item.id), ['c3']);
    expect(model.byId('c3')!.number, 3);
  });

  test('two tanks on the back become doubles drawn once', () {
    final model = composeFigure([
      item('t1', EquipmentType.tank),
      item('t2', EquipmentType.tank),
      item('t3', EquipmentType.tank),
    ]);
    expect(model.byId('t1')!.zone, FigureZone.backTank);
    expect(model.byId('t1')!.pieceIds, ['tank_doubles_back']);
    expect(model.byId('t2')!.zone, FigureZone.backTank);
    expect(model.byId('t2')!.pieceIds, isEmpty);
    expect(model.byId('t3')!.zone, FigureZone.stageLeft);
    expect(model.byId('t3')!.pieceIds, ['tank_stage_front']);
  });

  test('a sidemount harness sends tanks to the sides', () {
    final model = composeFigure([
      item('t1', EquipmentType.tank),
      item('t2', EquipmentType.tank),
      item(
        'h',
        EquipmentType.bcd,
        attributes: {EquipmentAttrKeys.bcdStyle: 'sidemount'},
      ),
    ]);
    expect(model.byId('t1')!.zone, FigureZone.sidemountLeft);
    expect(model.byId('t2')!.zone, FigureZone.sidemountRight);
  });

  test('a BCD and a separate wing compete for the one back zone', () {
    final model = composeFigure([
      item('bcd', EquipmentType.bcd),
      item('wing', EquipmentType.wing),
    ]);
    expect(model.byId('bcd')!.zone, FigureZone.wing);
    expect(model.byId('wing')!.zone, isNull);
  });

  test(
    'a sidemount rig draws its sidemount BCD, and a jacket goes to the tray',
    () {
      // The harness makes the tanks sidemount, so the back must show the
      // harness's rigging, not a jacket's bladder, whatever the list order.
      final model = composeFigure([
        item('jacket', EquipmentType.bcd),
        item(
          'harness',
          EquipmentType.bcd,
          attributes: {EquipmentAttrKeys.bcdStyle: 'sidemount'},
        ),
        item('t1', EquipmentType.tank),
      ]);
      expect(model.byId('harness')!.zone, FigureZone.wing);
      expect(model.byId('jacket')!.zone, isNull);
      expect(model.byId('jacket')!.number, 1);
      expect(model.byId('t1')!.zone, FigureZone.sidemountLeft);
    },
  );

  test(
    'a back-mounted rebreather fills the back so a tank goes to a stage slot',
    () {
      final model = composeFigure([
        item('ccr', EquipmentType.rebreather),
        item('bailout', EquipmentType.tank),
      ]);
      expect(model.byId('ccr')!.zone, FigureZone.backTank);
      expect(model.byId('bailout')!.zone, FigureZone.stageLeft);
    },
  );

  test('a dive tank role places the tank regardless of the set rule', () {
    final model = composeFigure([
      item('l', EquipmentType.tank, tankRole: TankRole.sidemountLeft),
      item('r', EquipmentType.tank, tankRole: TankRole.sidemountRight),
      item('s', EquipmentType.tank, tankRole: TankRole.stage),
      item('d', EquipmentType.tank, tankRole: TankRole.deco),
    ]);
    expect(model.byId('l')!.zone, FigureZone.sidemountLeft);
    expect(model.byId('r')!.zone, FigureZone.sidemountRight);
    expect(model.byId('s')!.zone, FigureZone.stageLeft);
    expect(model.byId('d')!.zone, FigureZone.stageRight);
  });

  test('children are neither drawn nor numbered', () {
    final model = composeFigure([
      item('ccr', EquipmentType.rebreather),
      item('cell', EquipmentType.o2Cell, isChild: true),
      item('mask', EquipmentType.mask),
    ]);
    expect(model.byId('cell'), isNull);
    expect(model.byId('mask')!.number, 2);
    expect(model.itemCount, 2);
  });

  test('a top-level child type and a tool land in the tray, numbered', () {
    final model = composeFigure([
      item('cell', EquipmentType.o2Cell),
      item('tool', EquipmentType.tool),
    ]);
    expect(model.tray.map((p) => p.number), [1, 2]);
    expect(model.placed, isEmpty);
  });

  test(
    'a colour attribute wins over the type default, malformed ones lose',
    () {
      final model = composeFigure([
        item('red', EquipmentType.fins, attributes: {'color': '#FF0000'}),
        item('bad', EquipmentType.fins, attributes: {'color': '#12G'}),
        item('word', EquipmentType.mask, attributes: {'color': 'red'}),
        item('empty', EquipmentType.hood, attributes: {'color': ''}),
      ]);
      expect(model.byId('red')!.color, 0xFFFF0000);
      expect(model.byId('bad')!.color, FigureColors.black);
      expect(model.byId('word')!.color, FigureColors.black);
      expect(model.byId('empty')!.color, FigureColors.black);
    },
  );

  test(
    'sixty lights fill every candidate and overflow to the tray in order',
    () {
      final model = composeFigure([
        for (var i = 1; i <= 60; i++) item('l$i', EquipmentType.light),
      ]);
      expect(model.placed.length, 3);
      expect(model.tray.length, 57);
      expect(
        model.numbered.map((p) => p.number),
        List.generate(60, (i) => i + 1),
      );
      expect(model.numbered.map((p) => p.item.id).toSet().length, 60);
    },
  );

  test('numbered lists placed and tray items in number order', () {
    final model = composeFigure([
      item('tool', EquipmentType.tool),
      item('mask', EquipmentType.mask),
    ]);
    expect(model.numbered.map((p) => p.item.id), ['tool', 'mask']);
  });

  test('a signed or short hex is not a colour', () {
    expect(parseFigureColor('#-00001'), isNull);
    expect(parseFigureColor('#+FFFFF'), isNull);
    expect(parseFigureColor('#0a0B0c'), 0xFF0A0B0C);
  });
}
