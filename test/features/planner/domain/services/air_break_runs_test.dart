import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/planner/domain/services/air_break_runs.dart';

const _policy = AirBreakPolicy(o2Seconds: 720, breakSeconds: 360);

void main() {
  group('airBreakTankIdFor', () {
    const breakStop = DecoStop(
      depthMeters: 6,
      durationSeconds: 1800,
      airBreakSeconds: 360,
    );
    final offersAir = OptimalOcAscentGas(
      gases: const [
        AvailableGas(fN2: 0.79, fHe: 0, maxPpO2Mod: 66),
        AvailableGas(fN2: 0, fHe: 0, maxPpO2Mod: 6),
      ],
      maxPpO2: 1.6,
    );
    String tankFor(double fO2, double fHe) => fO2 < 0.5 ? 'air' : 'rich';

    test('finds the cylinder holding the break gas', () {
      expect(
        airBreakTankIdFor(
          breakStop,
          plan: offersAir,
          stopTankId: 'o2',
          tankForGas: tankFor,
        ),
        'air',
      );
    });

    test('stays on the stop cylinder when no break gas is offered', () {
      expect(
        airBreakTankIdFor(
          breakStop,
          plan: FixedAscentGas(fN2: 0),
          stopTankId: 'o2',
          tankForGas: tankFor,
        ),
        'o2',
      );
    });

    test('names no cylinder on a stop with no break', () {
      expect(
        airBreakTankIdFor(
          const DecoStop(depthMeters: 6, durationSeconds: 1800),
          plan: offersAir,
          stopTankId: 'o2',
          tankForGas: tankFor,
        ),
        isNull,
      );
    });
  });

  group('airBreakRuns', () {
    test('a stop shorter than one O2 period is all O2', () {
      expect(airBreakRuns(600, _policy), [(onBreak: false, seconds: 600)]);
    });

    test('alternates O2 and the break gas through the cycle', () {
      expect(airBreakRuns(1800, _policy), [
        (onBreak: false, seconds: 720),
        (onBreak: true, seconds: 360),
        (onBreak: false, seconds: 720),
      ]);
    });

    test('a part minute follows the minute it falls in', () {
      // Minute 12 starts the break, so its 30 seconds are on the break gas,
      // as the scheduler loads them.
      expect(airBreakRuns(750, _policy), [
        (onBreak: false, seconds: 720),
        (onBreak: true, seconds: 30),
      ]);
    });

    test('takes each whole minute\'s gas from where the minute starts', () {
      // With a 90 second O2 period the second minute starts inside it and
      // the third starts on the break, as the scheduler counts them.
      const policy = AirBreakPolicy(o2Seconds: 90, breakSeconds: 60);
      expect(airBreakRuns(240, policy), [
        (onBreak: false, seconds: 120),
        (onBreak: true, seconds: 60),
        (onBreak: false, seconds: 60),
      ]);
    });

    test('an empty stop has no runs', () {
      expect(airBreakRuns(0, _policy), isEmpty);
    });
  });
}
