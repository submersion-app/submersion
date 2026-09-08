import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Which SAC rate each authored leg is charged at used to come from its
/// declared `SegmentType` (`bottom | descent` -> bottom SAC, everything else
/// -> deco SAC). It now comes from the derived phase (`descent | level` ->
/// bottom SAC, `ascent | stop` -> deco SAC), which is the one branch of the
/// old segment type that had a numeric consequence.
///
/// These tests pin that mapping by perturbing one SAC rate at a time and
/// checking exactly which legs move, rather than asserting a single total
/// that any change anywhere would break.

const _air = GasMix(o2: 21);
const _airTank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);

// Descend to 30 m over 3 min, 20 min on the bottom, up to 6 m over 3 min,
// 5 min there. The last two legs resolve to ascent and stop.
List<PlanSegment> _segments() => [
  PlanSegment.travel(
    id: 'seg-1',
    fromDepth: 0,
    targetDepth: 30,
    ratePerMinute: 10, // 3 min
    tankId: 'tank-1',
    gasMix: _air,
    order: 0,
  ),
  PlanSegment.hold(
    id: 'seg-2',
    depth: 30,
    durationMinutes: 20,
    tankId: 'tank-1',
    gasMix: _air,
    order: 1,
  ),
  PlanSegment.travel(
    id: 'seg-3',
    fromDepth: 30,
    targetDepth: 6,
    ratePerMinute: 8, // 3 min
    tankId: 'tank-1',
    gasMix: _air,
    order: 2,
  ),
  PlanSegment.hold(
    id: 'seg-4',
    depth: 6,
    durationMinutes: 5,
    tankId: 'tank-1',
    gasMix: _air,
    order: 3,
  ),
];

domain.DivePlan _plan({required double sacBottom, required double sacDeco}) =>
    domain.DivePlan(
      id: 'plan-1',
      name: 'SAC phase test',
      gfLow: 30,
      gfHigh: 70,
      sacBottom: sacBottom,
      sacDeco: sacDeco,
      segments: _segments(),
      tanks: const [_airTank],
      createdAt: DateTime(2026, 9, 2),
      updatedAt: DateTime(2026, 9, 2),
    );

double _litersUsed(domain.DivePlan plan) =>
    const PlanEngine().compute(plan).tankUsages.single.litersUsed;

void main() {
  const env = DiveEnvironment.standard;

  test('only the descent and level legs are charged at the bottom SAC', () {
    // Raising the bottom SAC by 1 L/min must add exactly the descent leg's
    // and the level leg's bar-minutes, and nothing else. If an ascent or a
    // stop leg were still on the bottom SAC, the delta would be larger.
    final descentBarMinutes = 3 * env.pressureAtDepth(15); // avg of 0 and 30
    final levelBarMinutes = 20 * env.pressureAtDepth(30);
    final expectedDelta = descentBarMinutes + levelBarMinutes;

    final base = _litersUsed(_plan(sacBottom: 20, sacDeco: 12));
    final raised = _litersUsed(_plan(sacBottom: 21, sacDeco: 12));

    expect(raised - base, closeTo(expectedDelta, 0.01));
  });

  test('the ascent and stop legs are charged at the deco SAC', () {
    // Raising the deco SAC by 1 L/min moves the authored ascent and stop
    // legs, plus the computed ascent tail, so this is a lower bound: it can
    // only hold if both authored legs are on the deco SAC.
    final ascentBarMinutes = 3 * env.pressureAtDepth(18); // avg of 30 and 6
    final stopBarMinutes = 5 * env.pressureAtDepth(6);
    final authoredDelta = ascentBarMinutes + stopBarMinutes;

    final base = _litersUsed(_plan(sacBottom: 20, sacDeco: 12));
    final raised = _litersUsed(_plan(sacBottom: 20, sacDeco: 13));

    expect(raised - base, greaterThan(authoredDelta - 0.01));
  });
}
