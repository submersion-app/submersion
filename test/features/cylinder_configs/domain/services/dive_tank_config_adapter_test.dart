import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/domain/services/dive_tank_config_adapter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  final now = DateTime.utc(2026, 8, 5);
  const adapter = DiveTankConfigAdapter();

  String newId(int index) => 'new-$index';

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

  test('an empty dive gets every cylinder, with gas and roles', () {
    final result = adapter.apply(
      tanks: const [],
      items: [
        cfg(id: 'a', role: TankRole.diluent, order: 0, o2: 18, he: 45),
        cfg(id: 'b', role: TankRole.oxygenSupply, order: 1, o2: 100),
        cfg(id: 'c', role: TankRole.bailout, order: 2, o2: 21),
      ],
      newId: newId,
    );

    expect(result.added, 3);
    expect(result.kept, 0);
    expect(result.tanks.map((t) => t.role), [
      TankRole.diluent,
      TankRole.oxygenSupply,
      TankRole.bailout,
    ]);
    expect(result.tanks.first.gasMix.o2, 18);
    expect(result.tanks.first.gasMix.he, 45);
    expect(result.tanks[1].gasMix.o2, 100);
  });

  test('a downloaded gas mix survives the merge untouched', () {
    final result = adapter.apply(
      tanks: [
        const DiveTank(
          id: 't1',
          role: TankRole.diluent,
          gasMix: GasMix(o2: 21, he: 0),
        ),
      ],
      items: [
        cfg(id: 'a', role: TankRole.diluent, o2: 18, he: 45, pressure: 232),
      ],
      newId: newId,
    );

    expect(result.kept, 1);
    expect(result.added, 0);

    final diluent = result.tanks.single;
    expect(diluent.id, 't1');
    expect(diluent.gasMix.o2, 21, reason: 'downloaded gas must not change');
    expect(diluent.gasMix.he, 0);
    expect(diluent.workingPressure, 232, reason: 'null column is filled');
  });

  test('only null fields are filled on a claimed tank', () {
    final result = adapter.apply(
      tanks: [
        const DiveTank(
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
      newId: newId,
    );

    final tank = result.tanks.single;
    expect(tank.volume, 11.1, reason: 'already set');
    expect(tank.name, 'Downloaded', reason: 'already set');
    expect(tank.workingPressure, 207);
    expect(tank.material, TankMaterial.aluminum);
    expect(tank.startPressure, 200);
  });

  test('applying twice is idempotent and reports no change', () {
    final items = [
      cfg(id: 'a', role: TankRole.diluent, order: 0, o2: 18, he: 45),
      cfg(id: 'b', role: TankRole.bailout, order: 1),
    ];

    final first = adapter.apply(tanks: const [], items: items, newId: newId);
    expect(first.changed, isTrue);

    final second = adapter.apply(
      tanks: first.tanks,
      items: items,
      newId: newId,
    );

    expect(second.added, 0);
    expect(second.kept, 2);
    expect(second.tanks, hasLength(2));
    // kept is non-zero here, so counts alone cannot distinguish "matched
    // everything, changed nothing" from real work.
    expect(second.changed, isFalse);
  });

  test('a claim that fills a null field counts as a change', () {
    final result = adapter.apply(
      tanks: [const DiveTank(id: 't1', role: TankRole.diluent)],
      items: [cfg(id: 'a', role: TankRole.diluent, pressure: 232)],
      newId: newId,
    );

    expect(result.added, 0);
    expect(result.kept, 1);
    expect(result.changed, isTrue);
  });

  test('existing tanks the config does not mention are preserved', () {
    final result = adapter.apply(
      tanks: [
        const DiveTank(id: 't1', role: TankRole.stage, order: 0),
        const DiveTank(id: 't2', role: TankRole.diluent, order: 1),
      ],
      items: [cfg(id: 'a', role: TankRole.diluent)],
      newId: newId,
    );

    expect(result.tanks.map((t) => t.id), ['t1', 't2']);
    expect(result.kept, 1);
    expect(result.added, 0);
  });

  test('inserted tanks continue the existing order and sort last', () {
    final result = adapter.apply(
      tanks: [const DiveTank(id: 't1', role: TankRole.stage, order: 4)],
      items: [
        cfg(id: 'a', role: TankRole.diluent, order: 0),
        cfg(id: 'b', role: TankRole.bailout, order: 1),
      ],
      newId: newId,
    );

    expect(result.tanks.map((t) => t.order), [4, 5, 6]);
    expect(result.tanks.map((t) => t.id), ['t1', 'new-0', 'new-1']);
  });

  test('an empty configuration leaves the list alone', () {
    final tanks = [const DiveTank(id: 't1', role: TankRole.diluent)];
    final result = adapter.apply(tanks: tanks, items: const [], newId: newId);

    expect(result.tanks, tanks);
    expect(result.added, 0);
    expect(result.kept, 0);
  });
}
