import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';

/// Bailout cylinders carrying the same mix share the bailout between them
/// instead of the first one taking all of it (#4138).
const _air = GasMix(o2: 21);
const _ean50 = GasMix(o2: 50);
const _diluent = DiveTank(
  id: 'dil',
  volume: 3,
  startPressure: 200,
  gasMix: _air,
  role: TankRole.diluent,
);

DiveTank _bailout(
  String id, {
  double volume = 7,
  double pressure = 200,
  GasMix mix = _air,
}) => DiveTank(
  id: id,
  volume: volume,
  startPressure: pressure,
  gasMix: mix,
  role: TankRole.bailout,
);

domain.DivePlan _plan(List<DiveTank> bailouts, {List<PlanSegment>? segments}) =>
    domain.DivePlan(
      id: 'plan-4138',
      name: 'two bailouts',
      mode: domain.PlanMode.ccr,
      gfLow: 50,
      gfHigh: 80,
      problemSolvingMinutes: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      tanks: [_diluent, ...bailouts],
      segments:
          segments ??
          [
            PlanSegment.travel(
              id: 'descent',
              fromDepth: 0,
              targetDepth: 40,
              tankId: 'dil',
              gasMix: _air,
              order: 0,
              ratePerMinute: 18,
            ),
            PlanSegment.hold(
              id: 'bottom',
              depth: 40,
              durationMinutes: 40,
              tankId: 'dil',
              gasMix: _air,
              order: 1,
            ),
          ],
    );

PlanTankUsage _usage(BailoutOutcome outcome, String id) =>
    outcome.bailoutTankUsages.firstWhere((u) => u.tankId == id);

double _totalUsed(BailoutOutcome outcome) =>
    outcome.bailoutTankUsages.fold(0.0, (sum, u) => sum + u.litersUsed);

void main() {
  const solver = BailoutSolver();

  test('the plan needs more than one cylinder holds', () {
    final outcome = solver.solve(_plan([_bailout('a'), _bailout('b')]))!;

    expect(
      outcome.worstCase.litersRequired,
      greaterThan(_usage(outcome, 'a').totalLiters!),
    );
  });

  test('two identical cylinders of one mix share the bailout evenly', () {
    // Big enough together, not alone: the case the first one overdrew.
    final outcome = solver.solve(
      _plan([
        _bailout('a', volume: 12, pressure: 232),
        _bailout('b', volume: 12, pressure: 232),
      ]),
    )!;
    final a = _usage(outcome, 'a');
    final b = _usage(outcome, 'b');

    expect(outcome.worstCase.litersRequired, greaterThan(a.totalLiters!));
    expect(
      outcome.worstCase.litersRequired,
      lessThan(a.totalLiters! + b.totalLiters!),
    );
    expect(a.litersUsed, closeTo(b.litersUsed, 1e-6));
    expect(a.remainingPressure, closeTo(b.remainingPressure!, 1e-6));
    expect(b.litersUsed, greaterThan(0));
    expect(a.reserveViolation, isFalse);
    expect(b.reserveViolation, isFalse);
  });

  test('the shares still add up to the worst case', () {
    final outcome = solver.solve(_plan([_bailout('a'), _bailout('b')]))!;

    expect(_totalUsed(outcome), closeTo(outcome.worstCase.litersRequired, 1.0));
  });

  test('a bigger cylinder takes a bigger share, to the same fraction', () {
    final outcome = solver.solve(
      _plan([_bailout('small', volume: 7), _bailout('big', volume: 11)]),
    )!;
    final small = _usage(outcome, 'small');
    final big = _usage(outcome, 'big');

    expect(
      small.litersUsed / small.totalLiters!,
      closeTo(big.litersUsed / big.totalLiters!, 1e-6),
    );
    expect(big.litersUsed, greaterThan(small.litersUsed));
  });

  test('a shortfall shows on every cylinder of the mix, not the first', () {
    final outcome = solver.solve(
      _plan([_bailout('a', volume: 3), _bailout('b', volume: 3)]),
    )!;
    final a = _usage(outcome, 'a');
    final b = _usage(outcome, 'b');

    expect(a.remainingPressure, lessThan(0));
    expect(b.remainingPressure, lessThan(0));
    expect(a.remainingPressure, closeTo(b.remainingPressure!, 1e-6));
    expect(a.reserveViolation, isTrue);
    expect(b.reserveViolation, isTrue);
  });

  test('a cylinder of another mix keeps only what its own mix used', () {
    final shared = solver.solve(_plan([_bailout('a'), _bailout('b')]))!;
    final withDeco = solver.solve(
      _plan([_bailout('a'), _bailout('b'), _bailout('deco', mix: _ean50)]),
    )!;
    final a = _usage(withDeco, 'a');
    final b = _usage(withDeco, 'b');

    expect(a.litersUsed, closeTo(b.litersUsed, 1e-6));
    expect(_usage(withDeco, 'deco').litersUsed, greaterThan(0));
    // The deco gas takes over the shallow stops, so the air pair gives less.
    expect(a.litersUsed, lessThan(_usage(shared, 'a').litersUsed));
  });

  test('gas an authored off-loop leg already took is balanced against', () {
    // Ten minutes off the loop on cylinder a at 40 m, then back on the loop:
    // the bailout draws b first, so both end at the same fraction.
    final outcome = solver.solve(
      _plan(
        [_bailout('a'), _bailout('b')],
        segments: [
          PlanSegment.travel(
            id: 'descent',
            fromDepth: 0,
            targetDepth: 40,
            tankId: 'dil',
            gasMix: _air,
            order: 0,
            ratePerMinute: 18,
          ),
          PlanSegment.hold(
            id: 'off-loop',
            depth: 40,
            durationMinutes: 4,
            tankId: 'a',
            gasMix: _air,
            order: 1,
            diveModeOverride: domain.PlanMode.oc,
          ),
          PlanSegment.hold(
            id: 'bottom',
            depth: 40,
            durationMinutes: 36,
            tankId: 'dil',
            gasMix: _air,
            order: 2,
          ),
        ],
      ),
    )!;
    final a = _usage(outcome, 'a');
    final b = _usage(outcome, 'b');

    expect(a.litersUsed, closeTo(b.litersUsed, 1e-6));
    expect(a.remainingPressure, closeTo(b.remainingPressure!, 1e-6));
  });
}
