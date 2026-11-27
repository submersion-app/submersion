import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_cns.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix();

const _backAir = DiveTank(
  id: 'back',
  volume: 40,
  startPressure: 200,
  gasMix: _air,
  role: TankRole.bailout,
);

const _ean50 = DiveTank(
  id: 'ean50',
  volume: 11,
  startPressure: 200,
  gasMix: GasMix(o2: 50),
  role: TankRole.bailout,
);

const _oxygen = DiveTank(
  id: 'o2',
  volume: 11,
  startPressure: 200,
  gasMix: GasMix(o2: 100),
  role: TankRole.bailout,
);

/// A 45 m / 40 min CCR dive on air diluent whose bailout owes deco.
domain.DivePlan _plan({
  List<DiveTank> bailout = const [_backAir],
  double startCns = 0,
  AirBreakPolicy? airBreaks,
}) => domain.DivePlan(
  id: 'cns',
  name: 'bailout cns',
  mode: domain.PlanMode.ccr,
  gfLow: 30,
  gfHigh: 70,
  lastStopDepth: 6,
  problemSolvingMinutes: 0,
  startCns: startCns,
  airBreaks: airBreaks,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  tanks: [
    const DiveTank(
      id: 'dil',
      volume: 3,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.diluent,
    ),
    ...bailout,
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: 45,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: 45,
      durationMinutes: 40,
      tankId: 'dil',
      gasMix: _air,
      order: 1,
    ),
  ],
);

void main() {
  const solver = BailoutSolver();
  const o2 = O2ToxicityCalculator();

  test('a direct ascent charges its travel at the mean depth', () {
    final environment = PlanEngine.environmentFor(_plan());
    const policy = SchedulePolicy();
    final bailoutPlan = const PlanEngineConfig().bailoutAscentGas([
      _backAir,
    ], environment);
    const point = BailoutPoint(
      runtimeSeconds: 600,
      depthMeters: 6,
      ttsSeconds: 40,
      litersRequired: 0,
      schedule: DecoSchedule(stops: [], ttsSeconds: 40),
    );

    final cns = bailoutAscentCns(
      point,
      bailoutPlan: bailoutPlan,
      policy: policy,
      environment: environment,
      o2: o2,
    );

    final seconds = policy.ascentSeconds(
      fromDepth: 6,
      toDepth: 0,
      phase: AscentPhase.surfacingAfter(AscentPhase.toFirstStop),
    );
    expect(
      cns,
      closeTo(
        o2.calculateCnsForSegment(
          environment.pressureAtDepth(3) * 0.21,
          seconds,
        ),
        1e-9,
      ),
    );
  });

  test("the bailout CNS carries the plan's starting CNS", () {
    final fresh = solver.solve(_plan())!;
    final repetitive = solver.solve(_plan(startCns: 30))!;

    expect(
      repetitive.worstCaseCnsEnd - fresh.worstCaseCnsEnd,
      closeTo(30, 1e-9),
    );
  });

  test("a richer bailout gas raises the ascent's CNS", () {
    final airOnly = solver.solve(_plan())!;
    final withEan50 = solver.solve(_plan(bailout: const [_backAir, _ean50]))!;

    expect(withEan50.worstCaseCnsEnd, greaterThan(airOnly.worstCaseCnsEnd));
  });

  /// The CNS [outcome]'s OC ascent charges on its own, with the policy and
  /// gases the solver uses for [plan].
  double ascentCnsOf(domain.DivePlan plan, BailoutOutcome outcome) {
    final environment = PlanEngine.environmentFor(plan);
    final config = const PlanEngineConfig().resolvedFor(plan);
    return bailoutAscentCns(
      outcome.worstCase,
      bailoutPlan: config.bailoutAscentGas(outcome.bailoutTanks, environment),
      policy: SchedulePolicy(
        lastStopDepth: config.lastStopDepth,
        ascentRate: config.ascentRate,
        intermediateAscentRate: config.intermediateAscentRate,
        shallowAscentRate: config.shallowAscentRate,
        finalAscentRate: config.finalAscentRate,
        descentRate: config.descentRate,
        gasSwitchStopSeconds: config.gasSwitchStopSeconds,
        snapStopsToWholeMinutes: true,
        airBreaks: config.airBreaksFor(plan),
        minStopSecondsByDepth: plan.stopMinimums,
      ),
      environment: environment,
      o2: o2,
    );
  }

  test('the loop exposure up to the worst case counts', () {
    final plan = _plan();
    final outcome = solver.solve(plan)!;

    final ascentOnly = ascentCnsOf(plan, outcome);
    expect(ascentOnly, greaterThan(0));
    expect(outcome.worstCaseCnsEnd, greaterThan(ascentOnly + 1));
  });

  test("the loop exposure matches the plan's own CNS at the worst case", () {
    final plan = _plan();
    final outcome = solver.solve(plan)!;
    final bottom = const PlanEngine().compute(plan).segmentOutcomes.last;
    expect(outcome.worstCase.runtimeSeconds, bottom.endRuntime);

    expect(
      outcome.worstCaseCnsEnd - ascentCnsOf(plan, outcome),
      closeTo(bottom.cns, 0.5),
    );
  });

  test('an air break is charged on the break gas', () {
    const bailout = [_backAir, _oxygen];
    final withoutBreaks = solver.solve(_plan(bailout: bailout))!;
    final withBreaks = solver.solve(
      _plan(bailout: bailout, airBreaks: const AirBreakPolicy()),
    )!;
    expect(
      withBreaks.worstCase.schedule.stops.last.airBreakSeconds,
      greaterThan(0),
    );

    expect(withBreaks.worstCaseCnsEnd, lessThan(withoutBreaks.worstCaseCnsEnd));
  });
}
