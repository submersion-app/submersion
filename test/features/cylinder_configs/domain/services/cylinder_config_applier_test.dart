import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/domain/services/cylinder_config_applier.dart';

void main() {
  final now = DateTime.utc(2026, 8, 5);
  const applier = CylinderConfigApplier();

  CylinderConfigItem cfg({
    required String id,
    required TankRole role,
    int order = 0,
    double o2 = 21,
    double he = 0,
    double? volume,
    double? pressure,
    TankMaterial? material,
    double? startPressure,
    String? label,
  }) => CylinderConfigItem(
    id: id,
    configId: 'c1',
    sortOrder: order,
    tankRole: role,
    o2Percent: o2,
    hePercent: he,
    volumeL: volume,
    workingPressureBar: pressure,
    tankMaterial: material,
    defaultStartPressureBar: startPressure,
    label: label,
    createdAt: now,
    updatedAt: now,
  );

  ExistingTank tank({
    required String id,
    required TankRole role,
    double? volume,
    double? pressure,
    TankMaterial? material,
    double? startPressure,
    String? name,
    int order = 0,
  }) => ExistingTank(
    id: id,
    tankRole: role,
    volumeL: volume,
    workingPressureBar: pressure,
    tankMaterial: material,
    startPressureBar: startPressure,
    tankName: name,
    tankOrder: order,
  );

  test('an empty dive gets every cylinder inserted, in sort order', () {
    final plan = applier.plan(
      existing: const [],
      items: [
        cfg(id: 'b', role: TankRole.oxygenSupply, order: 1),
        cfg(id: 'a', role: TankRole.diluent, order: 0),
        cfg(id: 'c', role: TankRole.bailout, order: 2),
      ],
    );

    expect(plan.insertedCount, 3);
    expect(plan.keptCount, 0);
    expect(plan.ops.whereType<FillTank>(), isEmpty);

    final inserts = plan.ops.whereType<InsertTank>().toList();
    expect(inserts.map((o) => o.item.tankRole), [
      TankRole.diluent,
      TankRole.oxygenSupply,
      TankRole.bailout,
    ]);
    expect(inserts.map((o) => o.tankOrder), [0, 1, 2]);
  });

  test('inserted tank order continues after the existing maximum', () {
    final plan = applier.plan(
      existing: [tank(id: 't1', role: TankRole.diluent, order: 7)],
      items: [
        cfg(id: 'a', role: TankRole.diluent, order: 0),
        cfg(id: 'b', role: TankRole.bailout, order: 1),
      ],
    );

    final inserts = plan.ops.whereType<InsertTank>().toList();
    expect(inserts, hasLength(1));
    expect(inserts.single.tankOrder, 8);
  });

  test('a downloaded gas mix is never overwritten', () {
    // The config carries a spec value so the claim is observable as a
    // FillTank; the point is that the trimix in the config reaches the
    // dive's air-filled diluent through no field of that op.
    final plan = applier.plan(
      existing: [tank(id: 't1', role: TankRole.diluent)],
      items: [
        cfg(id: 'a', role: TankRole.diluent, o2: 18, he: 45, pressure: 232),
      ],
    );

    expect(plan.insertedCount, 0);
    expect(plan.keptCount, 1);

    final fill = plan.ops.whereType<FillTank>().single;
    expect(fill.tankId, 't1');
    expect(fill.workingPressureBar, 232, reason: 'null column is filled');

    // FillTank has no gas fields at all, so overwriting a mix is not
    // expressible rather than merely discouraged. This is a compile-time
    // guarantee; the runtime check below just pins the op's shape.
    expect(fill.volumeL, isNull);
    expect(fill.tankName, isNull);
  });

  test('only null columns are filled on a claimed tank', () {
    final plan = applier.plan(
      existing: [
        tank(
          id: 't1',
          role: TankRole.bailout,
          volume: 11.1,
          name: 'Downloaded',
        ),
      ],
      items: [
        cfg(
          id: 'a',
          role: TankRole.bailout,
          volume: 5.7,
          pressure: 207,
          material: TankMaterial.aluminum,
          startPressure: 200,
          label: 'Bailout 1',
        ),
      ],
    );

    final fill = plan.ops.whereType<FillTank>().single;
    expect(fill.volumeL, isNull, reason: 'already 11.1, must not be touched');
    expect(fill.tankName, isNull, reason: 'already named');
    expect(fill.workingPressureBar, 207);
    expect(fill.tankMaterial, TankMaterial.aluminum);
    expect(fill.startPressureBar, 200);
  });

  test('duplicate roles claim one existing tank each, then insert', () {
    final plan = applier.plan(
      existing: [tank(id: 't1', role: TankRole.bailout, order: 0)],
      items: [
        cfg(id: 'a', role: TankRole.bailout, order: 0, pressure: 207),
        cfg(id: 'b', role: TankRole.bailout, order: 1, pressure: 232),
      ],
    );

    expect(plan.keptCount, 1);
    expect(plan.insertedCount, 1);
    expect(plan.ops.whereType<FillTank>().single.tankId, 't1');
    expect(
      plan.ops.whereType<InsertTank>().single.item.workingPressureBar,
      232,
    );
  });

  test('two existing tanks of one role are both claimed before inserting', () {
    // Distinct pressures make each claim observable and pin the pairing:
    // item a -> t1, item b -> t2, in sort order.
    final plan = applier.plan(
      existing: [
        tank(id: 't1', role: TankRole.bailout, order: 0),
        tank(id: 't2', role: TankRole.bailout, order: 1),
      ],
      items: [
        cfg(id: 'a', role: TankRole.bailout, order: 0, pressure: 207),
        cfg(id: 'b', role: TankRole.bailout, order: 1, pressure: 232),
      ],
    );

    expect(plan.keptCount, 2);
    expect(plan.insertedCount, 0);

    final fills = plan.ops.whereType<FillTank>().toList();
    expect(fills.map((o) => o.tankId), ['t1', 't2']);
    expect(fills.map((o) => o.workingPressureBar), [207, 232]);
  });

  test('extra existing tanks the config does not mention are left alone', () {
    final plan = applier.plan(
      existing: [
        tank(id: 't1', role: TankRole.diluent),
        tank(id: 't2', role: TankRole.stage),
      ],
      items: [cfg(id: 'a', role: TankRole.diluent, pressure: 232)],
    );

    expect(plan.keptCount, 1);
    expect(plan.insertedCount, 0);
    // Only the diluent is touched; the stage bottle produces no op at all.
    expect(plan.ops.whereType<FillTank>().map((o) => o.tankId), ['t1']);
  });

  test('a claimed tank needing no fill produces no FillTank op', () {
    final plan = applier.plan(
      existing: [
        tank(
          id: 't1',
          role: TankRole.diluent,
          volume: 3,
          pressure: 232,
          material: TankMaterial.steel,
          startPressure: 200,
          name: 'Dil',
        ),
      ],
      items: [cfg(id: 'a', role: TankRole.diluent, volume: 3, pressure: 232)],
    );

    expect(plan.keptCount, 1);
    expect(plan.ops, isEmpty);
  });

  test('an empty config is a no-op', () {
    final plan = applier.plan(
      existing: [tank(id: 't1', role: TankRole.diluent)],
      items: const [],
    );
    expect(plan.ops, isEmpty);
    expect(plan.insertedCount, 0);
    expect(plan.keptCount, 0);
  });

  test('planning is pure: the input lists are not mutated', () {
    final items = [
      cfg(id: 'b', role: TankRole.bailout, order: 1),
      cfg(id: 'a', role: TankRole.diluent, order: 0),
    ];
    final existing = [tank(id: 't1', role: TankRole.diluent)];

    applier.plan(existing: existing, items: items);

    expect(items.map((i) => i.id), ['b', 'a'], reason: 'caller order intact');
    expect(existing, hasLength(1));
  });
}
