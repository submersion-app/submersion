import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/breathing_gas_switches.dart';

/// A downloaded computer can attach a gas switch to the suit inflation
/// bottle when its gas list holds that bottle's mix, which is air in
/// practice. Dropping the switch would keep the diver on the previous gas
/// (a deco mix, say) and understate deco, so it moves to the breathing
/// cylinder on the same mix (issue #4243).
void main() {
  const back = DiveTank(
    id: 'back',
    name: 'Back',
    gasMix: GasMix(o2: 21),
    role: TankRole.backGas,
  );
  const deco = DiveTank(
    id: 'deco',
    name: 'Deco',
    gasMix: GasMix(o2: 50),
    role: TankRole.deco,
  );
  const suitAir = DiveTank(
    id: 'suit',
    name: 'Suit',
    gasMix: GasMix(o2: 21),
    role: TankRole.suitInflation,
  );
  final created = DateTime.utc(2026, 11, 6);

  GasSwitch raw(String id, String tankId, int t) => GasSwitch(
    id: id,
    diveId: 'd',
    timestamp: t,
    tankId: tankId,
    depth: 6,
    createdAt: created,
    computerId: 'pc',
  );

  GasSwitchWithTank withTank(GasSwitch sw, DiveTank tank) => GasSwitchWithTank(
    gasSwitch: sw,
    tankName: tank.name ?? '',
    gasMix: tank.gasMix.name,
    o2Fraction: tank.gasMix.o2 / 100,
    heFraction: tank.gasMix.he / 100,
  );

  group('breathingRawGasSwitches', () {
    test('moves an air suit switch to the air back gas', () {
      final result = breathingRawGasSwitches(
        [raw('1', 'deco', 600), raw('2', 'suit', 1200)],
        const [back, deco, suitAir],
      );

      expect(result, [raw('1', 'deco', 600), raw('2', 'back', 1200)]);
    });

    test('prefers the SAC reference cylinder among several matches', () {
      const stageAir = DiveTank(
        id: 'stageAir',
        gasMix: GasMix(o2: 21),
        role: TankRole.stage,
      );
      final result = breathingRawGasSwitches(
        [raw('1', 'suit', 60)],
        const [suitAir, stageAir, back],
      );

      expect(result.single.tankId, 'back');
    });

    test('takes the first breathing match when the reference differs', () {
      const stageAir = DiveTank(
        id: 'stageAir',
        gasMix: GasMix(o2: 21),
        role: TankRole.stage,
      );
      const backNx = DiveTank(
        id: 'backNx',
        gasMix: GasMix(o2: 32),
        role: TankRole.backGas,
      );
      final result = breathingRawGasSwitches(
        [raw('1', 'suit', 60)],
        const [suitAir, backNx, stageAir],
      );

      expect(result.single.tankId, 'stageAir');
    });

    test('drops a suit switch when no breathing cylinder holds its mix', () {
      const suitArgon = DiveTank(
        id: 'suit',
        gasMix: GasMix(o2: 0),
        role: TankRole.suitInflation,
      );
      final result = breathingRawGasSwitches(
        [raw('1', 'deco', 600), raw('2', 'suit', 1200)],
        const [back, deco, suitArgon],
      );

      expect(result, [raw('1', 'deco', 600)]);
    });

    test('leaves breathing and unknown-tank switches alone', () {
      final switches = [raw('1', 'deco', 600), raw('2', 'gone', 900)];

      expect(
        breathingRawGasSwitches(switches, const [back, deco, suitAir]),
        switches,
      );
    });
  });

  group('breathingGasSwitches', () {
    test('re-labels a moved switch with its new cylinder', () {
      final result = breathingGasSwitches(
        [withTank(raw('2', 'suit', 1200), suitAir)],
        const [back, deco, suitAir],
      );

      expect(result, [withTank(raw('2', 'back', 1200), back)]);
    });

    test('drops a switch it cannot move', () {
      const suitArgon = DiveTank(
        id: 'suit',
        gasMix: GasMix(o2: 0),
        role: TankRole.suitInflation,
      );

      expect(
        breathingGasSwitches(
          [withTank(raw('2', 'suit', 1200), suitArgon)],
          const [back, suitArgon],
        ),
        isEmpty,
      );
    });
  });
}
