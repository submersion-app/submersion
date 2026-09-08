import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/services/dive_tank_config_adapter.dart';
import 'package:submersion/features/cylinder_configs/domain/services/tank_config_capture.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A rig entered in the planner can be saved as a configuration and each
/// cylinder picked back into another plan. The two directions must be exact
/// inverses for the fields a configuration carries, or a save-then-pick round
/// trip would quietly change the tank.
void main() {
  const capture = TankConfigCapture();
  const adapter = DiveTankConfigAdapter();
  final now = DateTime(2026, 9, 2);

  const back = DiveTank(
    id: 'back',
    name: 'D12',
    volume: 24,
    workingPressure: 232,
    startPressure: 200,
    gasMix: GasMix(o2: 21),
    role: TankRole.backGas,
    material: TankMaterial.steel,
    order: 0,
  );
  const stage = DiveTank(
    id: 'stage',
    name: 'S80 EAN50',
    volume: 11.1,
    workingPressure: 207,
    startPressure: 200,
    gasMix: GasMix(o2: 50),
    role: TankRole.deco,
    material: TankMaterial.aluminum,
    order: 1,
    isTravelGas: true,
    decoSwitchDepth: 21,
  );

  test('captures every tank in order, field for field', () {
    final items = capture.fromTanks(
      tanks: const [stage, back], // out of order on purpose
      configId: 'cfg',
      newId: (i) => 'item-$i',
      now: now,
    );

    expect(items.map((i) => i.label), ['D12', 'S80 EAN50']);
    expect(items.map((i) => i.sortOrder), [0, 1]);
    expect(items.map((i) => i.id), ['item-0', 'item-1']);
    expect(items.every((i) => i.configId == 'cfg'), isTrue);

    final s = items[1];
    expect(s.tankRole, TankRole.deco);
    expect(s.volumeL, 11.1);
    expect(s.workingPressureBar, 207);
    expect(s.tankMaterial, TankMaterial.aluminum);
    expect(s.o2Percent, 50);
    expect(s.hePercent, 0);
    expect(s.defaultStartPressureBar, 200);
    expect(s.createdAt, now);
  });

  test('a saved cylinder picked back into a plan is the same tank', () {
    final items = capture.fromTanks(
      tanks: const [back, stage],
      configId: 'cfg',
      newId: (i) => 'item-$i',
      now: now,
    );
    final picked = adapter.tankFromItem(items[1], id: 'new', order: 3);

    // Everything a configuration carries survives the round trip.
    expect(picked.id, 'new');
    expect(picked.order, 3);
    expect(picked.name, stage.name);
    expect(picked.volume, stage.volume);
    expect(picked.workingPressure, stage.workingPressure);
    expect(picked.startPressure, stage.startPressure);
    expect(picked.gasMix, stage.gasMix);
    expect(picked.role, stage.role);
    expect(picked.material, stage.material);
    // What a configuration deliberately does not carry: plan-specific facts.
    expect(picked.isTravelGas, isFalse);
    expect(picked.decoSwitchDepth, isNull);
  });

  test('an empty id is left for the repository to mint', () {
    final items = capture.fromTanks(
      tanks: const [back],
      configId: 'cfg',
      newId: (_) => '',
    );
    expect(items.single.id, isEmpty);
  });
}
