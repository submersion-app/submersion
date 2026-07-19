import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/planner/domain/services/recreational_ndl_solver.dart';

/// Validates the recreational NDL-maximization solver. The solver defines the
/// no-deco boundary by the model's ascent schedule being empty; these tests
/// reconstruct that boundary independently, check monotonicity and a sane
/// absolute range, and cross-check against the model's own ndlSeconds so two
/// independent NDL definitions corroborate each other.
void main() {
  const air = OpenCircuit(fO2: 0.21);
  const policy = SchedulePolicy(ascentRate: 10, stopIncrement: 3);
  const descentRate = 18.0;

  BuhlmannGf model({double gf = 1.0}) =>
      BuhlmannGf(gfLow: gf, gfHigh: gf, policy: policy);

  RecreationalNdlSolver solver({double gf = 1.0}) => RecreationalNdlSolver(
    model: model(gf: gf),
    descentRate: descentRate,
  );

  // Reconstruct the solver's own no-deco criterion using a fresh model, so the
  // invariant check does not depend on the solver's internals.
  bool noDecoAfter(double depth, int bottomSeconds, {double gf = 1.0}) {
    final m = model(gf: gf);
    final descentSeconds = (depth / descentRate * 60).round();
    var state = m.applySegment(
      m.initial(),
      DecoSegment(
        startDepth: 0,
        endDepth: depth,
        durationSeconds: descentSeconds,
      ),
      air,
    );
    if (bottomSeconds > 0) {
      state = m.applySegment(
        state,
        DecoSegment(
          startDepth: depth,
          endDepth: depth,
          durationSeconds: bottomSeconds,
        ),
        air,
      );
    }
    return m
        .schedule(
          state,
          currentDepth: depth,
          gases: FixedAscentGas(fN2: air.fN2),
        )
        .stops
        .isEmpty;
  }

  test(
    'converges on the true boundary: no deco at max, deco one minute past',
    () {
      const depth = 30.0;
      final maxSec = solver().maxNoDecoBottomTimeSeconds(
        depthMeters: depth,
        breathing: air,
      );
      expect(maxSec, greaterThan(0));
      expect(noDecoAfter(depth, maxSec), isTrue);
      expect(noDecoAfter(depth, maxSec + 60), isFalse);
    },
  );

  test('deeper depths yield strictly shorter no-deco times', () {
    final s = solver();
    final ndl30 = s.maxNoDecoBottomTimeSeconds(depthMeters: 30, breathing: air);
    final ndl40 = s.maxNoDecoBottomTimeSeconds(depthMeters: 40, breathing: air);
    final ndl50 = s.maxNoDecoBottomTimeSeconds(depthMeters: 50, breathing: air);
    expect(ndl40, lessThan(ndl30));
    expect(ndl50, lessThan(ndl40));
  });

  test('air at 30 m gives a physically plausible NDL', () {
    final ndl = solver().maxNoDecoBottomTimeSeconds(
      depthMeters: 30,
      breathing: air,
    );
    final minutes = ndl / 60.0;
    // ZH-L16C direct-ascent NDL at 30 m is roughly 20-25 min; allow a wide
    // band to catch only order-of-magnitude errors.
    expect(minutes, greaterThan(12));
    expect(minutes, lessThan(35));
  });

  test('agrees with the model NDL at the bottom (independent cross-check)', () {
    final m = model();
    const depth = 40.0;
    final solverSec = RecreationalNdlSolver(
      model: m,
      descentRate: descentRate,
    ).maxNoDecoBottomTimeSeconds(depthMeters: depth, breathing: air);

    final descentSeconds = (depth / descentRate * 60).round();
    final afterDescent = m.applySegment(
      m.initial(),
      const DecoSegment(startDepth: 0, endDepth: depth, durationSeconds: 133),
      air,
    );
    // Sanity: our recomputed descent time matches the solver's.
    expect(descentSeconds, 133);
    final modelNdl = m.ndlSeconds(
      afterDescent,
      depthMeters: depth,
      breathing: air,
    );
    // Two independent NDL definitions (empty-schedule search vs the model's
    // ceiling-based ndl) should agree within a few minutes.
    expect((solverSec - modelNdl).abs(), lessThanOrEqualTo(180));
  });

  test('shallow dives return no obligation within the search cap', () {
    final ndl = solver().maxNoDecoBottomTimeSeconds(
      depthMeters: 10,
      breathing: air,
      capMinutes: 120,
    );
    expect(ndl, 120 * 60);
  });

  test('a conservatism margin backs off the reported time', () {
    final s = RecreationalNdlSolver(
      model: model(),
      descentRate: descentRate,
      marginSeconds: 3 * 60,
    );
    final withMargin = s.maxNoDecoBottomTimeSeconds(
      depthMeters: 30,
      breathing: air,
    );
    final withoutMargin = solver().maxNoDecoBottomTimeSeconds(
      depthMeters: 30,
      breathing: air,
    );
    expect(withMargin, withoutMargin - 3 * 60);
  });

  test('loop breathing without an explicit ascent plan is rejected', () {
    expect(
      () => solver().maxNoDecoBottomTimeSeconds(
        depthMeters: 30,
        breathing: PassiveScr(supplyFO2: 0.32),
      ),
      throwsArgumentError,
    );
  });

  test('a non-positive descent rate is rejected at construction', () {
    expect(
      () => RecreationalNdlSolver(model: model(), descentRate: 0),
      throwsArgumentError,
    );
    expect(
      () => RecreationalNdlSolver(model: model(), descentRate: -18),
      throwsArgumentError,
    );
  });

  test('a negative conservatism margin is rejected at construction', () {
    expect(
      () => RecreationalNdlSolver(model: model(), marginSeconds: -60),
      throwsArgumentError,
    );
  });

  test('a non-positive search cap is rejected', () {
    expect(
      () => solver().maxNoDecoBottomTimeSeconds(
        depthMeters: 30,
        breathing: air,
        capMinutes: 0,
      ),
      throwsArgumentError,
    );
  });
}
