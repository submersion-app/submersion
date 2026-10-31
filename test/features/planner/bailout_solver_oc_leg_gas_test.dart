import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// What an authored OC leg has already taken from the bailout cylinders is
/// not there for the bailout that follows it (#3898).
const _sac = 15.0;
const _air = GasMix(o2: 21);
const _diluentTank = DiveTank(
  id: 'dil',
  volume: 3,
  startPressure: 200,
  gasMix: _air,
  role: TankRole.diluent,
);

DiveTank _bailout({double volume = 11.1, double pressure = 207}) => DiveTank(
  id: 'bo',
  volume: volume,
  startPressure: pressure,
  gasMix: _air,
  role: TankRole.bailout,
);

final _descent = PlanSegment.travel(
  id: 'descent',
  fromDepth: 0,
  targetDepth: 30,
  tankId: 'dil',
  gasMix: _air,
  order: 0,
  ratePerMinute: 18,
);

PlanSegment _ocHold({
  String tankId = 'bo',
  double depth = 30,
  int minutes = 10,
  int order = 1,
}) => PlanSegment.hold(
  id: 'hold-$order',
  depth: depth,
  durationMinutes: minutes,
  tankId: tankId,
  gasMix: _air,
  order: order,
  diveModeOverride: domain.PlanMode.oc,
);

PlanSegment _loopHold({double depth = 30, int minutes = 10, int order = 1}) =>
    PlanSegment.hold(
      id: 'hold-$order',
      depth: depth,
      durationMinutes: minutes,
      tankId: 'dil',
      gasMix: _air,
      order: order,
    );

domain.DivePlan _plan(List<PlanSegment> segments, {DiveTank? bailout}) =>
    domain.DivePlan(
      id: 'plan-1',
      name: 'mixed',
      mode: domain.PlanMode.ccr,
      gfLow: 50,
      gfHigh: 80,
      problemSolvingMinutes: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      tanks: [_diluentTank, bailout ?? _bailout()],
      segments: segments,
    );

double _spent(domain.DivePlan plan, {required int minutes}) =>
    _sac * minutes * PlanEngine.environmentFor(plan).pressureAtDepth(30);

void main() {
  const solver = BailoutSolver();

  test('the gas an authored OC leg spent is not available afterwards', () {
    final loop = solver.solve(_plan([_descent, _loopHold()]))!;
    final plan = _plan([_descent, _ocHold()]);
    final outcome = solver.solve(plan)!;

    expect(
      outcome.availableLiters,
      closeTo(loop.availableLiters - _spent(plan, minutes: 10), 1e-6),
    );
  });

  test('the worst-case cylinder row counts that gas as used', () {
    final plan = _plan([_descent, _ocHold()]);
    final outcome = solver.solve(plan)!;

    expect(
      outcome.bailoutTankUsages.single.litersUsed,
      closeTo(
        outcome.worstCase.litersRequired + _spent(plan, minutes: 10),
        1e-6,
      ),
    );
  });

  test('problem-solving gas the plan spends on the cylinder is gone too', () {
    final plan = _plan([_descent, _ocHold()]);
    final withoutTime = solver.solve(plan)!;
    final withTime = solver.solve(plan.copyWith(problemSolvingMinutes: 2))!;
    final resolved = solver.config.resolvedFor(plan);
    final pressure = PlanEngine.environmentFor(plan).pressureAtDepth(30);

    expect(
      withoutTime.availableLiters - withTime.availableLiters,
      closeTo(resolved.sacBottom * resolved.buddyFactor * 2 * pressure, 1e-6),
    );
  });

  test('problem-solving gas adds to what the cylinder already spent', () {
    final plan = _plan([
      PlanSegment.travel(
        id: 'descent',
        fromDepth: 0,
        targetDepth: 15,
        tankId: 'dil',
        gasMix: _air,
        order: 0,
        ratePerMinute: 18,
      ),
      _ocHold(depth: 15, minutes: 10, order: 1),
      _ocHold(depth: 30, minutes: 10, order: 2),
    ]);
    final withTime = plan.copyWith(problemSolvingMinutes: 2);
    final used = const PlanEngine()
        .compute(withTime)
        .tankUsages
        .firstWhere((u) => u.tankId == 'bo')
        .litersUsed;
    final carried = solver.solve(_plan([_descent, _loopHold()]))!;

    expect(
      solver.solve(withTime)!.availableLiters,
      closeTo(carried.availableLiters - used, 1e-6),
    );
  });

  test('a rate-split leg spends what the plan charges it, once', () {
    final plan = _plan([
      _descent,
      const PlanSegment(
        id: 'split',
        targetDepth: 40,
        durationSeconds: 600,
        tankId: 'bo',
        gasMix: _air,
        order: 1,
        diveModeOverride: domain.PlanMode.oc,
        splitAtConfiguredRate: true,
      ),
    ]);
    final used = const PlanEngine()
        .compute(plan)
        .tankUsages
        .firstWhere((u) => u.tankId == 'bo')
        .litersUsed;
    final carried = solver.solve(_plan([_descent, _loopHold()]))!;

    expect(
      solver.solve(plan)!.availableLiters,
      closeTo(carried.availableLiters - used, 1e-6),
    );
  });

  test('never reports less than nothing available', () {
    final outcome = solver.solve(
      _plan([_descent, _ocHold(minutes: 40)], bailout: _bailout(volume: 3)),
    )!;

    expect(outcome.availableLiters, 0);
    expect(outcome.sufficient, isFalse);
  });

  test('sizes the bailout from the instant the cylinders fall shortest', () {
    // Deepest demand on the loop at 45 m, then a long OC leg shallower that
    // needs less to surface from but has eaten most of the gas.
    final loopThenOc = [
      PlanSegment.travel(
        id: 'descent',
        fromDepth: 0,
        targetDepth: 45,
        tankId: 'dil',
        gasMix: _air,
        order: 0,
        ratePerMinute: 18,
      ),
      _loopHold(depth: 45, minutes: 5),
      PlanSegment.travel(
        id: 'up',
        fromDepth: 45,
        targetDepth: 10,
        tankId: 'dil',
        gasMix: _air,
        order: 2,
        ratePerMinute: 9,
      ),
      _ocHold(depth: 10, minutes: 60, order: 3),
    ];
    final outcome = solver.solve(_plan(loopThenOc))!;
    final last = outcome.points.last;

    expect(outcome.worstCase.runtimeSeconds, last.runtimeSeconds);
  });

  test('gas an OC leg takes from the diluent leaves bailout untouched', () {
    final outcome = solver.solve(_plan([_descent, _ocHold(tankId: 'dil')]))!;
    final loop = solver.solve(_plan([_descent, _loopHold()]))!;

    expect(outcome.availableLiters, closeTo(loop.availableLiters, 1e-6));
  });

  test('a plan that never leaves the loop reads as it always did', () {
    final outcome = solver.solve(_plan([_descent, _loopHold()]))!;

    expect(
      outcome.bailoutTankUsages.single.litersUsed,
      closeTo(outcome.worstCase.litersRequired, 1e-6),
    );
  });
}
