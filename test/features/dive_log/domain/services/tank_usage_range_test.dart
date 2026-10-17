import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';

void main() {
  const back = DiveTank(id: 'back', volume: 12);
  const deco = DiveTank(
    id: 'deco',
    volume: 7,
    role: TankRole.deco,
    gasMix: GasMix(o2: 50),
  );

  GasSwitchWithTank switchTo(String tankId, int timestamp) {
    return GasSwitchWithTank(
      gasSwitch: GasSwitch(
        id: 'gs-$tankId-$timestamp',
        diveId: 'dive-1',
        timestamp: timestamp,
        tankId: tankId,
        createdAt: DateTime(2026),
      ),
      tankName: tankId,
      gasMix: 'mix',
      o2Fraction: 0.21,
    );
  }

  group('knownGasSwitches', () {
    test('keeps switches naming a current tank before the dive ends', () {
      final known = knownGasSwitches(
        const [back, deco],
        [
          switchTo('back', 0),
          switchTo('stale', 30),
          switchTo('deco', 2400),
          switchTo('deco', 3700),
        ],
        before: 3600,
      );

      expect(known.map((s) => s.gasSwitch.timestamp), [0, 2400]);
    });
  });

  group('activeTankAt', () {
    test('the back gas is breathed up to a switch late in the dive', () {
      // The grace for a starting gas runs from the dive's start, not from
      // the moment asked about: 50 s before the deco switch is back gas.
      final tank = activeTankAt(
        tanks: const [back, deco],
        gasSwitches: [switchTo('deco', 2400)],
        timestamp: 2350,
        diveStart: 0,
      );

      expect(tank?.id, 'back');
    });

    test('a switch in the first minute names the starting gas', () {
      final tank = activeTankAt(
        tanks: const [back, deco],
        gasSwitches: [switchTo('deco', 10), switchTo('back', 1200)],
        timestamp: 0,
        diveStart: 0,
      );

      expect(tank?.id, 'deco');
    });

    test('a stale switch is ignored', () {
      final tank = activeTankAt(
        tanks: const [deco, back],
        gasSwitches: [switchTo('stale', 10), switchTo('deco', 2400)],
        timestamp: 0,
        diveStart: 0,
      );

      expect(tank?.id, 'back');
    });

    test('with no switches the back gas is breathed', () {
      final tank = activeTankAt(
        tanks: const [deco, back],
        gasSwitches: null,
        timestamp: 600,
        diveStart: 0,
      );

      expect(tank?.id, 'back');
    });

    test('no tanks means no active tank', () {
      expect(
        activeTankAt(
          tanks: const [],
          gasSwitches: null,
          timestamp: 0,
          diveStart: 0,
        ),
        isNull,
      );
    });
  });
}
