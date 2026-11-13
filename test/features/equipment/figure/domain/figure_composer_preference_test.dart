import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// Where the diver says an item goes (issue #4493): a cylinder's Worn as,
/// a dive tank's role, and any item's position on the figure. The position
/// wins, then the dive role, then Worn as, then the set rule.
void main() {
  FigureItemInput item(
    String id,
    EquipmentType type, {
    Map<String, String?> attributes = const {},
    TankRole? tankRole,
  }) => FigureItemInput(
    id: id,
    type: type,
    name: id,
    attributes: attributes,
    tankRole: tankRole,
  );

  FigureItemInput tank(String id, {String? wornAs, String? position}) => item(
    id,
    EquipmentType.tank,
    attributes: {
      EquipmentAttrKeys.wornAs: ?wornAs,
      EquipmentAttrKeys.figurePosition: ?position,
    },
  );

  group('Worn as', () {
    test('sidemount cylinders go to the sides with no sidemount BCD', () {
      // The reporter's set: a wing-style BCD and two cylinders, which drew
      // as doubles on the back.
      final model = composeFigure([
        item('bcd', EquipmentType.bcd),
        tank('left', wornAs: 'sidemount_left'),
        tank('right', wornAs: 'sidemount_right'),
      ]);
      expect(model.byId('left')!.zone, FigureZone.sidemountLeft);
      expect(model.byId('right')!.zone, FigureZone.sidemountRight);
      expect(model.byId('left')!.pieceIds, ['tank_sidemount_back']);
    });

    test('the named side holds even when the right tank is listed first', () {
      final model = composeFigure([
        tank('right', wornAs: 'sidemount_right'),
        tank('left', wornAs: 'sidemount_left'),
      ]);
      expect(model.byId('left')!.zone, FigureZone.sidemountLeft);
      expect(model.byId('right')!.zone, FigureZone.sidemountRight);
    });

    test('a sidemount cylinder makes the rig sidemount, so an untagged '
        'third cylinder is a stage, not a back tank', () {
      final model = composeFigure([
        tank('plain'),
        tank('left', wornAs: 'sidemount_left'),
        tank('right', wornAs: 'sidemount_right'),
      ]);
      expect(model.byId('plain')!.zone, FigureZone.stageLeft);
    });

    test('a stage cylinder is clipped at the side beside a back tank', () {
      final model = composeFigure([
        tank('back'),
        tank('stage', wornAs: 'stage'),
      ]);
      expect(model.byId('back')!.zone, FigureZone.backTank);
      expect(model.byId('back')!.pieceIds, ['tank_single_back']);
      expect(model.byId('stage')!.zone, FigureZone.stageLeft);
    });

    test('two back cylinders are still drawn as doubles', () {
      final model = composeFigure([
        tank('a', wornAs: 'back'),
        tank('b', wornAs: 'back'),
      ]);
      expect(model.byId('a')!.pieceIds, ['tank_doubles_back']);
      expect(model.byId('b')!.pieceIds, isEmpty);
    });

    test('a back cylinder stays on the back in a sidemount BCD rig', () {
      final model = composeFigure([
        item(
          'harness',
          EquipmentType.bcd,
          attributes: {EquipmentAttrKeys.bcdStyle: 'sidemount'},
        ),
        tank('back', wornAs: 'back'),
      ]);
      expect(model.byId('back')!.zone, FigureZone.backTank);
    });
  });

  group('dive tank role', () {
    test('beats Worn as', () {
      final model = composeFigure([
        item(
          't',
          EquipmentType.tank,
          attributes: {EquipmentAttrKeys.wornAs: 'sidemount_left'},
          tankRole: TankRole.stage,
        ),
      ]);
      expect(model.byId('t')!.zone, FigureZone.stageLeft);
    });

    test('a role tank keeps its zone ahead of an earlier plain tank', () {
      // Placement walks the input order within a type; the plain tank must
      // not take the left side the role names.
      final model = composeFigure([
        tank('plain'),
        item('left', EquipmentType.tank, tankRole: TankRole.sidemountLeft),
      ], sidemountRig: true);
      expect(model.byId('left')!.zone, FigureZone.sidemountLeft);
      expect(model.byId('plain')!.zone, FigureZone.sidemountRight);
    });
  });

  group('position on the figure', () {
    test('beats Worn as and the dive role', () {
      final model = composeFigure([
        item(
          't',
          EquipmentType.tank,
          attributes: {
            EquipmentAttrKeys.wornAs: 'stage',
            EquipmentAttrKeys.figurePosition: 'sidemount_right',
          },
          tankRole: TankRole.backGas,
        ),
      ]);
      expect(model.byId('t')!.zone, FigureZone.sidemountRight);
    });

    test('moves a light to a chest clip', () {
      final model = composeFigure([
        item(
          'light',
          EquipmentType.light,
          attributes: {EquipmentAttrKeys.figurePosition: 'chest_right'},
        ),
      ]);
      expect(model.byId('light')!.zone, FigureZone.chestClipRight);
      expect(model.byId('light')!.pieceIds, ['light_clip_front']);
    });

    test('wins its zone over an item placed earlier by the set rule', () {
      // The computer ranks ahead of the compass and would take the left
      // wrist first; the compass the diver pinned there keeps it.
      final model = composeFigure([
        item('computer', EquipmentType.computer),
        item(
          'compass',
          EquipmentType.compass,
          attributes: {EquipmentAttrKeys.figurePosition: 'wrist_left'},
        ),
      ]);
      expect(model.byId('compass')!.zone, FigureZone.wristLeft);
      expect(model.byId('computer')!.zone, FigureZone.wristRight);
    });

    test('a spot the item has no artwork for is ignored', () {
      final model = composeFigure([
        item(
          'computer',
          EquipmentType.computer,
          attributes: {
            'mount': 'console',
            EquipmentAttrKeys.figurePosition: 'wrist_left',
          },
        ),
        item(
          'mask',
          EquipmentType.mask,
          attributes: {EquipmentAttrKeys.figurePosition: 'nonsense'},
        ),
      ]);
      expect(model.byId('computer')!.zone, FigureZone.console);
      expect(model.byId('mask')!.zone, FigureZone.face);
    });

    test('a full spot falls back to the set rule', () {
      final model = composeFigure([
        item(
          'a',
          EquipmentType.computer,
          attributes: {EquipmentAttrKeys.figurePosition: 'wrist_left'},
        ),
        item(
          'b',
          EquipmentType.computer,
          attributes: {EquipmentAttrKeys.figurePosition: 'wrist_left'},
        ),
      ]);
      expect(model.byId('a')!.zone, FigureZone.wristLeft);
      expect(model.byId('b')!.zone, FigureZone.wristRight);
    });

    test('placed items keep the canonical type order', () {
      final model = composeFigure([
        item('mask', EquipmentType.mask),
        item(
          'light',
          EquipmentType.light,
          attributes: {EquipmentAttrKeys.figurePosition: 'chest_left'},
        ),
      ]);
      final unpinned = composeFigure([
        item('mask', EquipmentType.mask),
        item('light', EquipmentType.light),
      ]);
      expect(
        model.placed.map((p) => p.item.id),
        unpinned.placed.map((p) => p.item.id),
      );
    });
  });

  test('a sidemount rig hint sends plain cylinders to the sides', () {
    final model = composeFigure([tank('a'), tank('b')], sidemountRig: true);
    expect(model.byId('a')!.zone, FigureZone.sidemountLeft);
    expect(model.byId('b')!.zone, FigureZone.sidemountRight);
  });
}
