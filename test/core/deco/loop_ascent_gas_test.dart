import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ccr_loop_ascent_gas.dart';
import 'package:submersion/core/deco/ascent/loop_ascent_gas.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

SemiClosedLoopAscentGas _loop(SemiClosedBreathing breathing) =>
    SemiClosedLoopAscentGas(
      environment: DiveEnvironment.standard,
      breathing: breathing,
    );

void main() {
  group('SemiClosedLoopAscentGas', () {
    test('a CMF loop is the same steady-state mix at every depth', () {
      final breathing = Scr(supplyFO2: 0.32, injectionRateLpm: 12);
      final loop = _loop(breathing);

      for (final depth in [40.0, 21.0, 6.0, 3.0]) {
        final gas = loop.gasForDepth(depth);
        // Steady state for 12 L/min of EAN32 at a VO2 of 1.3 L/min.
        expect(gas.fN2, closeTo(1 - 0.23738317757009342, 1e-12));
        expect(gas.fHe, 0.0);
      }
    });

    test('preserves the supply He:N2 ratio in the loop', () {
      final breathing = Scr(
        supplyFO2: 0.21,
        supplyFHe: 0.35,
        injectionRateLpm: 12,
      );
      final gas = _loop(breathing).gasForDepth(30);

      expect(gas.fHe / gas.fN2, closeTo(0.35 / 0.44, 1e-12));
    });

    test('a passive loop reproduces its inspired pressures at every depth', () {
      final breathing = PassiveScr(supplyFO2: 0.32, supplyFHe: 0.20);
      final loop = _loop(breathing);

      for (final depth in [40.0, 21.0, 6.0, 3.0, 0.0]) {
        final ambient = DiveEnvironment.standard.pressureAtDepth(depth);
        final pAlv = ambient - waterVaporPressure;
        final inspired = breathing.inspiredAt(ambient);
        final gas = loop.gasForDepth(depth);

        expect(gas.fN2 * pAlv, closeTo(inspired.pN2, 1e-12), reason: '$depth');
        expect(gas.fHe * pAlv, closeTo(inspired.pHe, 1e-12), reason: '$depth');
      }
    });

    test('reads the loop ppO2, not a stored fraction times ambient', () {
      final breathing = PassiveScr(supplyFO2: 0.32);
      final ambient = DiveEnvironment.standard.pressureAtDepth(21);

      expect(
        _loop(breathing).inspiredPpO2At(21),
        breathing.inspiredAt(ambient).pO2,
      );
    });

    test('carries the supply gas as its identity', () {
      final constantMass = _loop(
        Scr(supplyFO2: 0.21, supplyFHe: 0.35, injectionRateLpm: 12),
      );
      final passive = _loop(PassiveScr(supplyFO2: 0.18, supplyFHe: 0.45));

      expect(constantMass.supplyFO2, 0.21);
      expect(constantMass.supplyFHe, 0.35);
      expect(passive.supplyFO2, 0.18);
      expect(passive.supplyFHe, 0.45);
    });

    test('never switches gas and offers no air break', () {
      final loop = _loop(PassiveScr(supplyFO2: 0.32));

      expect(loop.switchDepthsBetween(40, 0), isEmpty);
      expect(loop.breakGasForDepth(6), isNull);
    });
  });

  test('a CCR loop is a loop whose supply gas is its diluent', () {
    final loop = CcrLoopAscentGas(
      environment: DiveEnvironment.standard,
      setpointLow: 0.7,
      setpointHigh: 1.3,
      switchDepth: 10,
      diluentFO2: 0.18,
      diluentFHe: 0.45,
    );

    expect(loop, isA<LoopAscentGas>());
    expect(loop.supplyFO2, 0.18);
    expect(loop.supplyFHe, 0.45);
    expect(loop.inspiredPpO2At(30), closeTo(1.3, 1e-9));
    expect(loop.inspiredPpO2At(6), closeTo(0.7, 1e-9));
  });

  test('a passive loop drifting with depth never earns a gas-switch stop', () {
    BuhlmannGf model(int gasSwitchStopSeconds) => BuhlmannGf(
      gfLow: .3,
      gfHigh: .7,
      environment: DiveEnvironment.standard,
      policy: SchedulePolicy(
        lastStopDepth: 3,
        gasSwitchStopSeconds: gasSwitchStopSeconds,
      ),
    );
    final breathing = PassiveScr(supplyFO2: 0.32);
    final free = model(0);
    final state = free.applySegment(
      free.initial(),
      const DecoSegment(startDepth: 40, endDepth: 40, durationSeconds: 2100),
      breathing,
    );

    final expected = free.schedule(
      state,
      currentDepth: 40,
      gases: _loop(breathing),
    );
    final floored = model(
      300,
    ).schedule(state, currentDepth: 40, gases: _loop(breathing));

    expect(expected.stops, isNotEmpty);
    expect(floored.ttsSeconds, expected.ttsSeconds);
  });
}
