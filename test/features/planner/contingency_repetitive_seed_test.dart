import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';
import 'package:submersion/features/planner/domain/services/tissue_seed.dart';

/// The contingency tables, the range table and the CCR bailout picture are
/// alternatives to the live plan, so a repetitive dive's residual loading
/// has to reach them just as it reaches the live plan (found while fixing
/// #3354, where the live plan's ceiling replay gained the same seed).

const _air = GasMix(o2: 21);
const _ean50 = GasMix(o2: 50);

TissueState _seed() {
  final prior = BuhlmannAlgorithm(gfLow: 0.40, gfHigh: 0.80)
    ..calculateSegment(depthMeters: 40.0, durationSeconds: 40 * 60);
  return seededTissueState(
    compartments: prior.compartments,
    surfaceInterval: const Duration(minutes: 30),
    gfLow: 0.40,
    gfHigh: 0.80,
  )!;
}

domain.DivePlan _ocPlan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Repetitive OC',
  gfLow: 40,
  gfHigh: 80,
  tanks: const [
    DiveTank(id: 'back', volume: 24, startPressure: 232, gasMix: _air),
    DiveTank(
      id: 'deco',
      volume: 11.1,
      startPressure: 207,
      gasMix: _ean50,
      role: TankRole.deco,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: 40,
      tankId: 'back',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: 40,
      durationMinutes: 20,
      tankId: 'back',
      gasMix: _air,
      order: 1,
    ),
  ],
  createdAt: DateTime(2026, 10, 16),
  updatedAt: DateTime(2026, 10, 16),
);

domain.DivePlan _ccrPlan() {
  const diluent = GasMix(o2: 18, he: 45);
  return domain.DivePlan(
    id: 'plan-2',
    name: 'Repetitive CCR',
    mode: domain.PlanMode.ccr,
    gfLow: 40,
    gfHigh: 80,
    tanks: const [
      DiveTank(
        id: 'dil',
        volume: 3,
        startPressure: 200,
        gasMix: diluent,
        role: TankRole.diluent,
      ),
      DiveTank(
        id: 'bo',
        volume: 11.1,
        startPressure: 207,
        gasMix: _ean50,
        role: TankRole.bailout,
      ),
    ],
    segments: [
      PlanSegment.travel(
        id: 'descent',
        fromDepth: 0,
        targetDepth: 40,
        tankId: 'dil',
        gasMix: diluent,
        order: 0,
        ratePerMinute: 18,
      ),
      PlanSegment.hold(
        id: 'bottom',
        depth: 40,
        durationMinutes: 20,
        tankId: 'dil',
        gasMix: diluent,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 10, 16),
    updatedAt: DateTime(2026, 10, 16),
  );
}

void main() {
  const engine = PlanEngine();
  const contingencies = ContingencyService();

  test('deviations carry the repetitive seed', () {
    final plan = _ocPlan();
    final seed = _seed();
    final fresh = contingencies.deviations(plan);
    final seeded = contingencies.deviations(plan, startState: seed);

    for (var i = 0; i < fresh.length; i++) {
      expect(
        seeded[i].outcome.totalDecoSeconds,
        engine.compute(seeded[i].plan, startState: seed).totalDecoSeconds,
      );
      expect(
        seeded[i].outcome.totalDecoSeconds,
        greaterThan(fresh[i].outcome.totalDecoSeconds),
      );
    }
    expect(
      contingencies
          .deviationFor(plan, 'deeper', startState: seed)!
          .outcome
          .totalDecoSeconds,
      seeded.first.outcome.totalDecoSeconds,
    );
  });

  test('lost-gas schedules carry the repetitive seed', () {
    final plan = _ocPlan();
    final seed = _seed();
    final fresh = contingencies.lostGasFor(plan, 'deco')!;
    final seeded = contingencies.lostGasFor(plan, 'deco', startState: seed)!;

    expect(
      seeded.outcome.totalDecoSeconds,
      greaterThan(fresh.outcome.totalDecoSeconds),
    );
    expect(
      contingencies
          .lostGas(plan, startState: seed)
          .single
          .outcome
          .totalDecoSeconds,
      seeded.outcome.totalDecoSeconds,
    );
  });

  test('range table cells carry the repetitive seed', () {
    final plan = _ocPlan();
    final seed = _seed();
    const service = RangeTableService();
    final table = service.compute(plan, startState: seed);

    final centre =
        table.cells[table.depthDeltas.indexOf(0)][table.timeDeltas.indexOf(0)]!;
    expect(
      centre.outcome.totalDecoSeconds,
      engine.compute(plan, startState: seed).totalDecoSeconds,
    );
    expect(
      centre.outcome.totalDecoSeconds,
      greaterThan(engine.compute(plan).totalDecoSeconds),
    );
  });

  test('the CCR bailout picture carries the repetitive seed', () {
    final plan = _ccrPlan();
    const solver = BailoutSolver();
    final fresh = solver.solve(plan)!;
    final seeded = solver.solve(plan, startState: _seed())!;

    expect(
      seeded.worstCase.ttsSeconds,
      greaterThan(fresh.worstCase.ttsSeconds),
    );
  });

  test('the bailout solver rejects a seed from another deco model', () {
    expect(
      () => const BailoutSolver().solve(
        _ccrPlan(),
        startState: const _ForeignState(),
      ),
      throwsArgumentError,
    );
  });
}

class _ForeignState implements TissueState {
  const _ForeignState();
}
