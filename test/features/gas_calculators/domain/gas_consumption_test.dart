import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart';
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';

final _al80 = TankSpec.fromPreset(TankPresets.al80);
final _steel12 = TankSpec.fromPreset(TankPresets.steel12);

void main() {
  group('rounding helpers', () {
    test('roundUpTo rounds toward a larger reserve', () {
      expect(roundUpTo(57.2, 10), 60);
      expect(roundUpTo(60.0, 10), 60);
      expect(roundUpTo(1566, 250), 1750);
    });

    test('roundDownTo rounds toward a shallower limit', () {
      expect(roundDownTo(35.16, 1), 35);
      expect(roundDownTo(31.94, 1), 31);
      expect(roundDownTo(35.0, 1), 35);
    });

    test('rounding a zero or negative value does not blow up', () {
      expect(roundUpTo(0, 10), 0);
      expect(roundDownTo(0, 1), 0);
    });
  });

  group('computeConsumption', () {
    test('20 m for 45 min at 15 L/min uses 2025 L', () {
      final r = computeConsumption(
        ConsumptionInputs(
          avgDepthMeters: 20,
          minutes: 45,
          sacLitersPerMin: 15,
          tank: _steel12,
        ),
      );
      // 15 L/min * 3 bar * 45 min = 2025 L.
      expect(r.litersConsumed, closeTo(2025, 0.1));
      expect(r.gasAtDepthLitersPerMin, closeTo(45, 0.1));
      // 2025 L / 12 L = 168.75 bar.
      expect(r.barConsumed, closeTo(168.75, 0.1));
    });

    test('uses the tank working pressure, not a hardcoded 200 bar', () {
      final r = computeConsumption(
        ConsumptionInputs(
          avgDepthMeters: 20,
          minutes: 45,
          sacLitersPerMin: 15,
          tank: _al80,
        ),
      );
      // AL80 is 206.843 bar, so remaining is 206.843 - consumed, not 200 -.
      expect(r.barRemaining, closeTo(206.843 - r.barConsumed, 0.01));
      expect(r.litersRemaining, closeTo(_al80.freeGasLiters - 2025, 1.0));
    });

    test('flags a plan that exceeds the cylinder', () {
      final r = computeConsumption(
        ConsumptionInputs(
          avgDepthMeters: 40,
          minutes: 90,
          sacLitersPerMin: 25,
          tank: _steel12,
        ),
      );
      expect(r.exceedsTank, isTrue);
    });

    test('a normal plan does not flag', () {
      final r = computeConsumption(
        ConsumptionInputs(
          avgDepthMeters: 20,
          minutes: 45,
          sacLitersPerMin: 15,
          tank: _steel12,
        ),
      );
      expect(r.exceedsTank, isFalse);
    });

    test('the exceeds threshold follows the tank, not a flat 200 bar', () {
      // 15 L/min at 20 m for 60 min is 2700 L. That is 209 bar in a 237 bar
      // HP100 (fits) but 225 bar in a 200 bar steel 12 (does not). The old
      // code compared every tank against a flat 200 bar, so it would have
      // called the HP100 plan a failure too.
      ConsumptionInputs on(TankSpec tank) => ConsumptionInputs(
        avgDepthMeters: 20,
        minutes: 60,
        sacLitersPerMin: 15,
        tank: tank,
      );

      final onHp100 = computeConsumption(
        on(TankSpec.fromPreset(TankPresets.hp100)),
      );
      expect(onHp100.barConsumed, closeTo(209.3, 0.5));
      expect(onHp100.exceedsTank, isFalse);

      final onSteel12 = computeConsumption(on(_steel12));
      expect(onSteel12.barConsumed, closeTo(225.0, 0.5));
      expect(onSteel12.exceedsTank, isTrue);
    });
  });
}
