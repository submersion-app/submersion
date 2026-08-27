import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _tank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);

domain.DivePlan _plan(List<PlanSegment> segments, domain.PlanMode mode) =>
    domain.DivePlan(
      id: 'plan-1',
      name: 'Per-segment test',
      gfLow: 30,
      gfHigh: 70,
      mode: mode,
      segments: segments,
      tanks: const [_tank],
      createdAt: DateTime(2026, 7, 17),
      updatedAt: DateTime(2026, 7, 17),
    );

List<PlanSegment> _segments({double? setpoint, domain.PlanMode? modeOverride}) {
  return [
    PlanSegment.descent(
      id: 'seg-1',
      targetDepth: 40,
      tankId: 'tank-1',
      gasMix: _air,
      order: 0,
    ),
    PlanSegment.bottom(
      id: 'seg-2',
      depth: 40,
      durationMinutes: 20,
      tankId: 'tank-1',
      gasMix: _air,
      order: 1,
    ).copyWith(setpointBar: setpoint, diveModeOverride: modeOverride),
  ];
}

void main() {
  test('a per-segment setpoint override changes CCR oxygen exposure', () {
    const engine = PlanEngine();
    final low = engine.compute(
      _plan(_segments(setpoint: 0.7), domain.PlanMode.ccr),
    );
    final high = engine.compute(
      _plan(_segments(setpoint: 1.3), domain.PlanMode.ccr),
    );
    // A higher loop pO2 accumulates more CNS on the bottom segment.
    expect(high.cnsEnd, greaterThan(low.cnsEnd));
  });

  test('a per-segment OC override on a CCR plan changes the outcome', () {
    const engine = PlanEngine();
    final pureCcr = engine.compute(_plan(_segments(), domain.PlanMode.ccr));
    final ccrWithOcBottom = engine.compute(
      _plan(_segments(modeOverride: domain.PlanMode.oc), domain.PlanMode.ccr),
    );
    // OC on the bottom breathes ambient-pO2 air (not the loop), so oxygen
    // exposure and/or tissue loading differ from a pure-CCR bottom.
    expect(ccrWithOcBottom.cnsEnd, isNot(closeTo(pureCcr.cnsEnd, 1e-9)));
  });
}
