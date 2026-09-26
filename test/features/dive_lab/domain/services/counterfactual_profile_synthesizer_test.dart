import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_lab/domain/services/counterfactual_profile_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const back = DiveTank(
  id: 'back',
  volume: 24,
  startPressure: 150,
  gasMix: GasMix(o2: 21),
  role: TankRole.backGas,
);
const deco50 = DiveTank(
  id: 'deco50',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 50),
  role: TankRole.deco,
);

domain.DivePlan _plan({
  int bottomMinutes = 10,
  List<DiveTank> tanks = const [back, deco50],
}) => domain.DivePlan(
  id: 'p',
  name: 'p',
  gfLow: 30,
  gfHigh: 70,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  tanks: tanks,
  // The remainder starts at depth: the zero-duration anchor puts the engine
  // there, as compileScenarioPlan does, so the hold resolves flat.
  segments: [
    PlanSegment.hold(
      id: 's0-anchor',
      depth: 45,
      durationMinutes: 0,
      tankId: 'back',
      gasMix: const GasMix(o2: 21),
    ),
    PlanSegment.hold(
      id: 's0',
      depth: 45,
      durationMinutes: bottomMinutes,
      tankId: 'back',
      gasMix: const GasMix(o2: 21),
      order: 1,
    ),
  ],
);

void main() {
  test('remainder starts at T, walks the bottom, stops, and surfaces', () {
    final plan = _plan();
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final r = synthesizeRemainder(
      plan: plan,
      outcome: outcome,
      startTimestamp: 1500,
      startDepth: 45,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
    );
    expect(r.timestamps.first, 1500);
    expect(r.depths.first, 45);
    expect(r.depths.last, 0);
    for (var i = 1; i < r.timestamps.length; i++) {
      expect(
        r.timestamps[i],
        greaterThan(r.timestamps[i - 1]),
        reason: 'sample $i',
      );
    }
    expect(r.bottomEndTimestamp, 1500 + 600);
    // Total synthesized duration = bottom + the engine's TTS from the bottom,
    // within per-leg rounding (one second per leg at most).
    expect(
      r.timestamps.last - 1500,
      closeTo(600 + outcome.ttsAtBottom, outcome.stops.length + 2),
    );
    // Stops appear as level holds at the outcome's stop depths.
    for (final stop in outcome.stops) {
      expect(
        r.depths.where((d) => (d - stop.depthMeters).abs() < 1e-9).length,
        greaterThan(1),
        reason: 'stop ${stop.depthMeters}',
      );
    }
  });

  test('gas segments switch to 50% on the ascent and name the tank', () {
    final plan = _plan();
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final r = synthesizeRemainder(
      plan: plan,
      outcome: outcome,
      startTimestamp: 0,
      startDepth: 45,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
    );
    expect(r.gasSegments.first.startTimestamp, 0);
    expect(r.gasSegments.first.fN2, airN2Fraction);
    expect(r.gasSegments.any((g) => (g.fN2 - 0.5).abs() < 1e-9), isTrue);
    expect(r.tankSwitches.map((s) => s.tankId), contains('deco50'));
    // The 50% switch happens no deeper than its MOD at 1.6 (22 m).
    final sw = r.tankSwitches.firstWhere((s) => s.tankId == 'deco50');
    final idx = r.timestamps.indexOf(sw.timestamp);
    expect(r.depths[idx], lessThanOrEqualTo(22.0 + 1e-6));
  });

  test('extraLastStopSeconds lengthens only the final stop', () {
    final plan = _plan();
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final base = synthesizeRemainder(
      plan: plan,
      outcome: outcome,
      startTimestamp: 0,
      startDepth: 45,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
    );
    final longer = synthesizeRemainder(
      plan: plan,
      outcome: outcome,
      startTimestamp: 0,
      startDepth: 45,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
      extraLastStopSeconds: 120,
    );
    expect(longer.timestamps.last - base.timestamps.last, 120);
  });

  test('loop mode emits setpoint segments', () {
    final plan = _plan(
      tanks: const [back],
    ).copyWith(mode: domain.PlanMode.ccr, setpointLow: 0.7, setpointHigh: 1.3);
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final r = synthesizeRemainder(
      plan: plan,
      outcome: outcome,
      startTimestamp: 0,
      startDepth: 45,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
      loop: const LoopSetpoints(
        low: 0.7,
        high: 1.3,
        switchDepth: 10,
        diluent: GasMix(o2: 21),
      ),
    );
    expect(r.gasSegments.first.setpoint, 1.3);
    expect(r.gasSegments.last.setpoint, 0.7);
  });

  test('a leg keeps one setpoint, chosen from its average depth', () {
    // PlanEngine picks the loop setpoint per leg from the leg's average
    // depth; the synthesized samples must not switch partway down a leg.
    final plan = domain.DivePlan(
      id: 'p',
      name: 'p',
      gfLow: 30,
      gfHigh: 70,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      tanks: const [back],
      mode: domain.PlanMode.ccr,
      setpointLow: 0.7,
      setpointHigh: 1.3,
      segments: [
        PlanSegment.hold(
          id: 'a',
          depth: 20,
          durationMinutes: 0,
          tankId: 'back',
          gasMix: const GasMix(o2: 21),
        ),
        const PlanSegment(
          id: 't',
          targetDepth: 40,
          durationSeconds: 120,
          tankId: 'back',
          gasMix: GasMix(o2: 21),
          order: 1,
        ),
        PlanSegment.hold(
          id: 'h',
          depth: 40,
          durationMinutes: 5,
          tankId: 'back',
          gasMix: const GasMix(o2: 21),
          order: 2,
        ),
      ],
    );
    const engine = PlanEngine();
    final r = synthesizeRemainder(
      plan: plan,
      outcome: engine.compute(plan),
      startTimestamp: 0,
      startDepth: 20,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
      loop: const LoopSetpoints(
        low: 0.7,
        high: 1.3,
        switchDepth: 30,
        diluent: GasMix(o2: 21),
      ),
    );
    // The 20 to 40 m leg averages exactly 30 m: not deeper than the switch
    // depth, so it stays on the low setpoint until the hold begins at 120 s.
    final firstHigh = r.gasSegments.firstWhere((g) => g.setpoint == 1.3);
    expect(firstHigh.startTimestamp, greaterThanOrEqualTo(120));
  });

  test('a switch between two cylinders of the same mix is recorded', () {
    const a = DiveTank(
      id: 'a',
      volume: 12,
      startPressure: 200,
      gasMix: GasMix(o2: 21),
      role: TankRole.backGas,
    );
    const b = DiveTank(
      id: 'b',
      volume: 12,
      startPressure: 200,
      gasMix: GasMix(o2: 21),
      role: TankRole.stage,
      order: 1,
    );
    final plan = domain.DivePlan(
      id: 'p',
      name: 'p',
      gfLow: 30,
      gfHigh: 70,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      tanks: const [a, b],
      segments: [
        PlanSegment.hold(
          id: 'anchor',
          depth: 30,
          durationMinutes: 0,
          tankId: 'a',
          gasMix: const GasMix(o2: 21),
        ),
        PlanSegment.hold(
          id: 'on-a',
          depth: 30,
          durationMinutes: 5,
          tankId: 'a',
          gasMix: const GasMix(o2: 21),
          order: 1,
        ),
        PlanSegment.hold(
          id: 'on-b',
          depth: 30,
          durationMinutes: 5,
          tankId: 'b',
          gasMix: const GasMix(o2: 21),
          order: 2,
        ),
      ],
    );
    const engine = PlanEngine();
    final r = synthesizeRemainder(
      plan: plan,
      outcome: engine.compute(plan),
      startTimestamp: 0,
      startDepth: 30,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
    );
    final toB = r.tankSwitches.where((s) => s.tankId == 'b');
    expect(toB, hasLength(1));
    expect(toB.single.timestamp, 300);
  });

  test('splice keeps the actual prefix and appends the remainder once', () {
    final plan = _plan();
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final r = synthesizeRemainder(
      plan: plan,
      outcome: outcome,
      startTimestamp: 20,
      startDepth: 45,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
    );
    final s = spliceCounterfactual(
      actualTimestamps: const [0, 10, 20, 30, 40],
      actualDepths: const [0, 20, 45, 45, 45],
      actualGasSegments: const [
        ProfileGasSegment(startTimestamp: 0, fN2: airN2Fraction),
      ],
      branchIndex: 2,
      remainder: r,
    );
    expect(s.timestamps.sublist(0, 3), [0, 10, 20]);
    expect(s.timestamps[3], r.timestamps[1]);
    expect(s.depths.length, s.timestamps.length);
    expect(s.gasSegments.first.startTimestamp, 0);
    for (var i = 1; i < s.timestamps.length; i++) {
      expect(s.timestamps[i], greaterThan(s.timestamps[i - 1]));
    }
  });
}
