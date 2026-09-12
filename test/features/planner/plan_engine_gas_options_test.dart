import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_best_mix.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _ean50 = GasMix(o2: 50);

domain.DivePlan _decoPlan({
  double? ppO2Bottom,
  double? ppO2Deco,
  double sacFactor = 2.0,
  int problemSolvingMinutes = 2,
}) {
  const backTank = DiveTank(
    id: 'back',
    volume: 24.0,
    startPressure: 232,
    gasMix: _air,
    role: TankRole.backGas,
  );
  const decoTank = DiveTank(
    id: 'deco',
    volume: 11.1,
    startPressure: 232,
    gasMix: _ean50,
    role: TankRole.deco,
  );
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Gas options test',
    gfLow: 40,
    gfHigh: 80,
    ppO2Bottom: ppO2Bottom,
    ppO2Deco: ppO2Deco,
    sacFactor: sacFactor,
    problemSolvingMinutes: problemSolvingMinutes,
    // Pin EN13319 so the 22 m / 18 m MOD figures in the ppO2Deco test
    // stay exact (10 m per bar). The planner's unset default is now salt.
    salinityPpt: DiveEnvironment.salinityPptFromDensity(
      DiveEnvironment.en13319Density,
    ),
    tanks: const [backTank, decoTank],
    segments: [
      PlanSegment.travel(
        id: 'seg-1',
        fromDepth: 0,
        targetDepth: 42.0,
        tankId: 'back',
        gasMix: _air,
        order: 0,
        ratePerMinute: 18.0,
      ),
      PlanSegment.hold(
        id: 'seg-2',
        depth: 42.0,
        durationMinutes: 30,
        tankId: 'back',
        gasMix: _air,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  const engine = PlanEngine();

  group('PlanEngine gas-option overrides', () {
    test(
      'a lower plan-level ppO2Bottom raises a ppO2 warning air alone would not',
      () {
        // Air at 52 m: ppO2 ~= 0.21 * 6.2 = 1.302 - under the 1.4 app-wide
        // working ceiling, but over a plan that dials it down to 1.2.
        const tank = DiveTank(
          id: 'back',
          volume: 24.0,
          startPressure: 232,
          gasMix: _air,
        );
        domain.DivePlan planAt(double depth, {double? ppO2Bottom}) =>
            domain.DivePlan(
              id: 'p',
              name: 'ppO2 override',
              gfLow: 40,
              gfHigh: 80,
              ppO2Bottom: ppO2Bottom,
              tanks: const [tank],
              segments: [
                PlanSegment.travel(
                  id: 's1',
                  fromDepth: 0,
                  targetDepth: depth,
                  tankId: 'back',
                  gasMix: _air,
                  order: 0,
                  ratePerMinute: 18.0,
                ),
                PlanSegment.hold(
                  id: 's2',
                  depth: depth,
                  durationMinutes: 5,
                  tankId: 'back',
                  gasMix: _air,
                  order: 1,
                ),
              ],
              createdAt: DateTime(2026, 7, 5),
              updatedAt: DateTime(2026, 7, 5),
            );

        final withoutOverride = engine.compute(planAt(52.0));
        expect(
          withoutOverride.issues.map((i) => i.type),
          isNot(contains(PlanIssueType.ppO2High)),
        );

        final withOverride = engine.compute(planAt(52.0, ppO2Bottom: 1.2));
        expect(
          withOverride.issues.map((i) => i.type),
          contains(PlanIssueType.ppO2High),
        );
      },
    );

    test(
      'a lower plan-level ppO2Deco forces an earlier mandatory gas-switch stop',
      () {
        // EAN50's MOD is 22 m at ppO2 1.6 (comfortably past this plan's
        // deepest natural ceiling stop, 15 m) but only 18 m at ppO2 1.4 -
        // which falls strictly between two natural stops and so forces an
        // extra mandatory switch stop the permissive ceiling never needs.
        final permissive = engine.compute(_decoPlan(ppO2Deco: 1.6));
        final strict = engine.compute(_decoPlan(ppO2Deco: 1.4));
        final permissiveDepths = permissive.stops
            .map((s) => s.depthMeters)
            .toSet();
        final strictDepths = strict.stops.map((s) => s.depthMeters).toSet();

        expect(permissiveDepths, isNot(contains(18.0)));
        expect(strictDepths, contains(18.0));
        final switchStop = strict.stops.firstWhere(
          (s) => s.depthMeters == 18.0,
        );
        expect(switchStop.gasFO2, closeTo(0.5, 1e-9));
      },
    );

    test('sacFactor scales the minimum-gas figure by hand calculation', () {
      final low = engine.compute(_decoPlan(sacFactor: 1.0));
      final high = engine.compute(_decoPlan(sacFactor: 4.0));
      final lowMinGas = low.tankUsages
          .firstWhere((u) => u.tankId == 'back')
          .minGasBar!;
      final highMinGas = high.tankUsages
          .firstWhere((u) => u.tankId == 'back')
          .minGasBar!;
      // Everything else held equal, minGasBar is directly proportional to
      // sacFactor (it multiplies the whole rock-bottom SAC).
      expect(highMinGas / lowMinGas, closeTo(4.0, 1e-6));
    });

    test(
      'problem-solving time adds N minutes at max depth times SAC factor to used gas',
      () {
        const engine = PlanEngine();
        final none = engine.compute(
          _decoPlan(sacFactor: 2.0, problemSolvingMinutes: 0),
        );
        final extra = engine.compute(
          _decoPlan(sacFactor: 2.0, problemSolvingMinutes: 2),
        );
        final env = DiveEnvironment.forConditions(
          salinityPpt: DiveEnvironment.salinityPptFromDensity(
            DiveEnvironment.en13319Density,
          ),
        );
        final expected = 15.0 * 2.0 * 2 * env.pressureAtDepth(42.0);
        final noneUsed = none.tankUsages
            .firstWhere((u) => u.tankId == 'back')
            .litersUsed;
        final extraUsed = extra.tankUsages
            .firstWhere((u) => u.tankId == 'back')
            .litersUsed;
        expect(extraUsed - noneUsed, closeTo(expected, 1.0));
      },
    );

    test(
      'problemSolvingMinutes changes the minimum-gas figure by hand calculation',
      () {
        final plan = _decoPlan();
        final short = engine.compute(plan.copyWith(problemSolvingMinutes: 1));
        final long = engine.compute(plan.copyWith(problemSolvingMinutes: 5));
        final shortMinGas = short.tankUsages
            .firstWhere((u) => u.tankId == 'back')
            .minGasBar!;
        final longMinGas = long.tankUsages
            .firstWhere((u) => u.tankId == 'back')
            .minGasBar!;
        expect(longMinGas, greaterThan(shortMinGas));
      },
    );
  });

  group('suggestBestMixForPlan', () {
    const config = PlanEngineConfig();

    test('a tighter bestMixEndMeters raises the suggested He fraction', () {
      final wide = suggestBestMixForPlan(
        _decoPlan().copyWith(bestMixEndMeters: 40.0),
        config,
        depthMeters: 60.0,
      );
      final narrow = suggestBestMixForPlan(
        _decoPlan().copyWith(bestMixEndMeters: 25.0),
        config,
        depthMeters: 60.0,
      );
      expect(wide.recommended.mix.he, lessThan(narrow.recommended.mix.he));
    });

    test('o2Narcotic = false lowers the He needed for the same END target', () {
      final narcotic = suggestBestMixForPlan(
        _decoPlan().copyWith(o2Narcotic: true),
        config,
        depthMeters: 60.0,
      );
      final notNarcotic = suggestBestMixForPlan(
        _decoPlan().copyWith(o2Narcotic: false),
        config,
        depthMeters: 60.0,
      );
      expect(
        notNarcotic.recommended.mix.he,
        lessThan(narcotic.recommended.mix.he),
      );
    });

    test('uses the deco ppO2 ceiling only when forDeco is set', () {
      final plan = _decoPlan(ppO2Bottom: 1.2, ppO2Deco: 1.6);
      final bottom = suggestBestMixForPlan(plan, config, depthMeters: 30.0);
      final deco = suggestBestMixForPlan(
        plan,
        config,
        depthMeters: 30.0,
        forDeco: true,
      );
      // A higher ppO2 ceiling allows a richer O2 fraction.
      expect(deco.idealO2Percent, greaterThan(bottom.idealO2Percent));
    });
  });
}
