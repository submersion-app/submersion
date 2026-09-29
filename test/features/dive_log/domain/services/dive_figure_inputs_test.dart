import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_figure_inputs.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
  );
  const hose = EquipmentItem(
    id: 'hose',
    name: 'Hose',
    type: EquipmentType.hose,
  );
  const left = EquipmentItem(
    id: 'left',
    name: 'Left tank',
    type: EquipmentType.tank,
  );
  const stage = EquipmentItem(
    id: 'stage',
    name: 'Stage',
    type: EquipmentType.tank,
  );
  final flat = EquipmentArrangement.defaults.copyWith(groupByType: false);
  String label(EquipmentType t) => t.name;

  test('only top-level rows, in the arranged order', () {
    final links = gearLinksFor(
      const [reg, hose, left],
      const [GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg')],
    );
    final ordered = [
      for (final g in arrangedDiveGear(links, flat, typeLabel: label))
        ...g.items,
    ];
    expect(ordered.map((i) => i.id), isNot(contains('hose')));
    expect(ordered.map((i) => i.id).toSet(), {'reg', 'left'});
  });

  test('the first linked tank by order gives the role', () {
    final roles = tankRolesByItem(const [
      DiveTank(id: 't2', order: 1, equipmentId: 'left'),
      DiveTank(
        id: 't1',
        order: 0,
        equipmentId: 'left',
        role: TankRole.sidemountLeft,
      ),
      DiveTank(id: 't3', order: 2, role: TankRole.stage),
      DiveTank(id: 't4', order: 3, equipmentId: 'stage', role: TankRole.stage),
    ]);
    expect(roles, {'left': TankRole.sidemountLeft, 'stage': TankRole.stage});
  });

  test('roles place tanks, and every row is numbered', () {
    final model = composeFigure(
      figureInputsForDive(
        const [reg, left, stage],
        const {
          'left': TankRole.sidemountLeft,
          'stage': TankRole.stage,
          'ghost': TankRole.deco,
        },
      ),
    );
    expect(model.itemCount, 3);
    expect(model.byId('left')!.zone, FigureZone.sidemountLeft);
    expect(
      model.byId('stage')!.zone,
      anyOf(FigureZone.stageLeft, FigureZone.stageRight),
    );
    expect(
      model.byId('ghost'),
      isNull,
      reason: 'a tank not in the gear is not drawn',
    );
  });

  test('a top-level row with a parent link is still numbered on a dive', () {
    // The tree promotes an orphaned part to the top level; the figure must
    // number it too, or its badge and label would disagree.
    const orphan = EquipmentItem(
      id: 'orphan',
      name: 'Second stage',
      type: EquipmentType.secondStage,
      parentEquipmentId: 'missing',
    );
    final model = composeFigure(figureInputsForDive(const [orphan], const {}));
    expect(model.itemCount, 1);
  });
}
