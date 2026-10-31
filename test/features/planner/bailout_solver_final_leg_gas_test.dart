import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';

const _air = GasMix();
const _ean50 = GasMix(o2: 50);

/// A bailout that owes no stops is one leg to the surface, and that leg still
/// crosses the switch to a richer bailout gas.
domain.DivePlan _noStopBailoutPlan() => domain.DivePlan(
  id: 'plan-1',
  name: 'no-stop bailout',
  mode: domain.PlanMode.ccr,
  gfLow: 50,
  gfHigh: 80,
  problemSolvingMinutes: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  tanks: const [
    DiveTank(
      id: 'dil',
      volume: 3,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.diluent,
    ),
    DiveTank(
      id: 'back',
      volume: 11,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.bailout,
    ),
    DiveTank(
      id: 'rich',
      volume: 7,
      startPressure: 200,
      gasMix: _ean50,
      role: TankRole.bailout,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: 30,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: 30,
      durationMinutes: 3,
      tankId: 'dil',
      gasMix: _air,
      order: 1,
    ),
  ],
);

void main() {
  const solver = BailoutSolver();

  test('a no-stop bailout splits its surface leg at the gas switch', () {
    final outcome = solver.solve(_noStopBailoutPlan())!;
    expect(outcome.worstCase.schedule.stops, isEmpty);

    final ascent = outcome.worstCaseRows
        .skip(outcome.ccrRows.length)
        .where((row) => row.kind == PlanScheduleRowKind.ascent)
        .toList();

    expect(ascent.map((row) => row.tankId), ['back', 'rich']);
    expect(ascent.last.depthMeters, 0);
    expect(ascent.last.endMeters, 0, reason: 'floored at the surface');
  });

  test('each bailout cylinder pays for its own stretch of that leg', () {
    final outcome = solver.solve(_noStopBailoutPlan())!;
    double used(String id) => outcome.bailoutTankUsages
        .singleWhere((usage) => usage.tankId == id)
        .litersUsed;

    expect(used('rich'), greaterThan(0));
    expect(
      used('back') + used('rich'),
      closeTo(outcome.worstCase.litersRequired, 1.0),
    );
  });
}
