import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _backTank = DiveTank(
  id: 'back',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);
const _o2Tank = DiveTank(
  id: 'o2',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: GasMix(o2: 100),
  role: TankRole.deco,
);

domain.DivePlan _plan({AirBreakPolicy? airBreaks}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Air break usage test',
    gfLow: 40,
    gfHigh: 80,
    airBreaks: airBreaks,
    tanks: const [_backTank, _o2Tank],
    segments: [
      PlanSegment.travel(
        id: 'seg-1',
        fromDepth: 0,
        targetDepth: 45.0,
        tankId: 'back',
        gasMix: _air,
        order: 0,
        ratePerMinute: 18.0,
      ),
      PlanSegment.hold(
        id: 'seg-2',
        depth: 45.0,
        durationMinutes: 45,
        tankId: 'back',
        gasMix: _air,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

double _litersFor(PlanOutcome outcome, String tankId) =>
    outcome.tankUsages.firstWhere((u) => u.tankId == tankId).litersUsed;

void main() {
  group('PlanEngine air-break tank attribution', () {
    test(
      'splits O2-stop gas consumption between the O2 tank and the break-gas tank',
      () {
        const engine = PlanEngine();
        final plan = _plan();
        final baseline = engine.compute(plan);
        final withBreaks = engine.compute(
          plan.copyWith(
            airBreaks: const AirBreakPolicy(o2Seconds: 720, breakSeconds: 360),
          ),
        );

        // Air breaks only ever apply within the O2 phase (<= 6 m); every
        // stop still on back gas must be untouched by turning them on, or
        // the deltas checked below would not isolate to the split itself.
        final baselineBackStops = baseline.stops
            .where((s) => s.tankId == 'back')
            .toList();
        final withBreaksBackStops = withBreaks.stops
            .where((s) => s.tankId == 'back')
            .toList();
        expect(withBreaksBackStops, baselineBackStops);
        expect(baseline.stops.every((s) => s.airBreakSeconds == 0), isTrue);

        final breakStops = withBreaks.stops
            .where((s) => s.airBreakSeconds > 0)
            .toList();
        expect(breakStops, isNotEmpty);

        final baselineO2 = _litersFor(baseline, 'o2');
        final withBreaksO2 = _litersFor(withBreaks, 'o2');
        final baselineBack = _litersFor(baseline, 'back');
        final withBreaksBack = _litersFor(withBreaks, 'back');

        // The O2 tank gives up gas, the break (back) gas tank picks it up.
        expect(withBreaksO2, lessThan(baselineO2));
        expect(withBreaksBack, greaterThan(baselineBack));

        // Exact accounting: with every other leg unchanged (asserted above),
        // the entire liters delta on each tank must come from the primary/
        // break split of the affected O2 stop(s) - not from double-charging
        // or dropping seconds. Same sac/pressure formula the engine uses
        // (salt water is the planner default when water type is unset).
        final environment = DiveEnvironment.forConditions(
          waterType: WaterType.salt,
        );
        final sac = plan.sacDecoEffective;
        var expectedBreakLiters = 0.0;
        var expectedPrimaryDelta = 0.0;
        for (final stop in breakStops) {
          final baselineStop = baseline.stops.firstWhere(
            (s) => s.depthMeters == stop.depthMeters,
          );
          final pressure = environment.pressureAtDepth(stop.depthMeters);
          expectedBreakLiters += sac * pressure * (stop.airBreakSeconds / 60.0);
          final primarySeconds = stop.durationSeconds - stop.airBreakSeconds;
          expectedPrimaryDelta +=
              sac *
              pressure *
              ((baselineStop.durationSeconds - primarySeconds) / 60.0);
        }

        expect(
          withBreaksBack - baselineBack,
          closeTo(expectedBreakLiters, 1e-6),
        );
        expect(baselineO2 - withBreaksO2, closeTo(expectedPrimaryDelta, 1e-6));
      },
    );
  });
}
