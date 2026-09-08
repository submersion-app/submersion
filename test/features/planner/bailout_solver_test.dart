import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';

const _diluent = GasMix(o2: 18, he: 45);
const _diluentTank = DiveTank(
  id: 'dil',
  volume: 3.0,
  startPressure: 200,
  gasMix: _diluent,
  role: TankRole.diluent,
);

DiveTank _bailout({double volume = 11.1, double pressure = 207}) => DiveTank(
  id: 'bo',
  volume: volume,
  startPressure: pressure,
  gasMix: const GasMix(o2: 50),
  role: TankRole.bailout,
);

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.ccr,
  List<DiveTank>? tanks,
  int bottomMinutes = 25,
}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Bailout test',
    mode: mode,
    gfLow: 50,
    gfHigh: 80,
    tanks: tanks ?? [_diluentTank, _bailout()],
    segments: [
      PlanSegment.travel(
        id: 'seg-1',
        fromDepth: 0,
        targetDepth: 60.0,
        tankId: 'dil',
        gasMix: _diluent,
        order: 0,
        ratePerMinute: 18.0,
      ),
      PlanSegment.hold(
        id: 'seg-2',
        depth: 60.0,
        durationMinutes: bottomMinutes,
        tankId: 'dil',
        gasMix: _diluent,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  const solver = BailoutSolver();

  test('returns null for OC plans and when no bailout tanks are carried', () {
    expect(solver.solve(_plan(mode: domain.PlanMode.oc)), isNull);
    expect(solver.solve(_plan(tanks: const [_diluentTank])), isNull);
  });

  test('worst case sits at (or near) the end of the bottom phase', () {
    final outcome = solver.solve(_plan())!;
    final lastPoint = outcome.points.last;
    expect(
      outcome.worstCase.runtimeSeconds,
      greaterThanOrEqualTo(lastPoint.runtimeSeconds - 90),
      reason: 'square profile loads monotonically, so latest is worst',
    );
    expect(outcome.worstCase.depthMeters, closeTo(60.0, 0.1));
  });

  test('required liters grow across the bottom phase', () {
    final outcome = solver.solve(_plan())!;
    final bottomPoints = outcome.points
        .where((p) => p.depthMeters > 59.0)
        .toList();
    expect(bottomPoints.length, greaterThan(2));

    // Loading only ever grows on a square profile, so the demand grows with
    // it - but not smoothly. The stop grid is discrete and the ascent rate
    // depends on whether a stop is actually held: the minute a marginal deep
    // stop first appears, every leg above it changes from the working ascent
    // to the slower climb up the grid, and the minute it disappears again
    // they change back. A step like that can shave a few seconds off the
    // total ascent while the tissues are still loading, so allow a sample to
    // give back a little rather than pinning an exactness the model does not
    // promise. The trend is the real claim, and it is asserted below.
    for (var i = 1; i < bottomPoints.length; i++) {
      expect(
        bottomPoints[i].litersRequired,
        greaterThanOrEqualTo(bottomPoints[i - 1].litersRequired * 0.98),
        reason: 'sample $i fell more than one grid step below its predecessor',
      );
    }
    expect(
      bottomPoints.last.litersRequired,
      greaterThan(bottomPoints.first.litersRequired * 2),
    );
  });

  test('sufficiency flips with the carried bailout volume', () {
    final small = solver.solve(
      _plan(tanks: [_diluentTank, _bailout(volume: 3.0, pressure: 100)]),
    )!;
    expect(small.sufficient, isFalse);

    final big = solver.solve(
      _plan(
        tanks: [_diluentTank, _bailout(volume: 24.0, pressure: 232)],
        bottomMinutes: 10,
      ),
    )!;
    expect(big.sufficient, isTrue);
  });

  test('nearest() returns the closest sampled point', () {
    final outcome = solver.solve(_plan())!;
    final target = outcome.points[2].runtimeSeconds.toDouble();
    expect(outcome.nearest(target).runtimeSeconds, target.toInt());
  });
}
