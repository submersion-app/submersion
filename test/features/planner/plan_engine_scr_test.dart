import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _tank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);

List<PlanSegment> _segments() => [
  PlanSegment.travel(
    id: 'seg-1',
    fromDepth: 0,
    targetDepth: 45,
    tankId: 'tank-1',
    gasMix: _air,
    order: 0,
    ratePerMinute: 18.0,
  ),
  PlanSegment.hold(
    id: 'seg-2',
    depth: 45,
    durationMinutes: 20,
    tankId: 'tank-1',
    gasMix: _air,
    order: 1,
  ),
];

domain.DivePlan _plan(domain.PlanMode mode) => domain.DivePlan(
  id: 'plan-1',
  name: 'SCR test',
  gfLow: 30,
  gfHigh: 70,
  mode: mode,
  segments: _segments(),
  tanks: const [_tank],
  createdAt: DateTime(2026, 7, 17),
  updatedAt: DateTime(2026, 7, 17),
);

void main() {
  test(
    'SCR ascent stays on the effective loop mix, even with rich OC tanks',
    () {
      const supply = GasMix(o2: 50, he: 10);
      final fO2 = ScrCalculator.calculateCmfSteadyStateFo2(
        injectionRateLpm: 12,
        supplyO2Percent: 50,
      )!;
      final effective = GasMix(o2: fO2 * 100, he: (1 - fO2) * 20);
      final scr = _plan(domain.PlanMode.scr).copyWith(
        tanks: [_tank.copyWith(gasMix: supply)],
        segments: [for (final s in _segments()) s.copyWith(gasMix: supply)],
      );
      final oc = scr.copyWith(
        mode: domain.PlanMode.oc,
        tanks: [_tank.copyWith(gasMix: effective)],
        segments: [for (final s in scr.segments) s.copyWith(gasMix: effective)],
      );
      const engine = PlanEngine();
      final actual = engine.compute(scr);
      final reference = engine.compute(oc);
      expect(actual.runtimeSeconds, reference.runtimeSeconds);
      expect(
        actual.stops.map((s) => (s.depthMeters, s.durationSeconds)),
        reference.stops.map((s) => (s.depthMeters, s.durationSeconds)),
      );
      expect(actual.stops.last.gasFO2, closeTo(fO2, 1e-10));
    },
  );

  test('PlanMode.scr parses from its stored string name', () {
    expect(domain.PlanMode.values.byName('scr'), domain.PlanMode.scr);
    expect(domain.PlanMode.scr.name, 'scr');
  });

  test('an SCR plan computes and differs from OC on the same profile', () {
    const engine = PlanEngine();
    final oc = engine.compute(_plan(domain.PlanMode.oc));
    final scr = engine.compute(_plan(domain.PlanMode.scr));

    // Both produce a runtime; the SCR loop pO2 differs from OC ambient pO2,
    // so oxygen exposure (CNS) is not identical.
    expect(scr.runtimeSeconds, greaterThan(0));
    expect(scr.cnsEnd, isNot(closeTo(oc.cnsEnd, 1e-9)));
  });

  test('PlanMode.pscr parses from its stored string name', () {
    expect(domain.PlanMode.values.byName('pscr'), domain.PlanMode.pscr);
    expect(domain.PlanMode.pscr.name, 'pscr');
  });

  test('a passive SCR plan depletes loop O2 below OC (lower CNS)', () {
    // Subsurface's default pSCR settings give an EAN32 loop that stays above
    // the hypoxia threshold at 30 m while sitting well below the OC ppO2.
    const engine = PlanEngine();
    final oc = engine.compute(_pscrPlan(domain.PlanMode.oc));
    final pscr = engine.compute(_pscrPlan(domain.PlanMode.pscr));

    expect(pscr.runtimeSeconds, greaterThan(0));
    // Loop O2 is metabolically depleted below the supply, so inspired ppO2 —
    // and therefore CNS accumulation — is strictly lower than open circuit.
    expect(pscr.cnsEnd, lessThan(oc.cnsEnd));
  });

  test('the pSCR ratio flows through config into the loop O2 drop', () {
    // Larger ratio -> more fresh gas -> smaller O2 drop -> higher inspired
    // ppO2 -> more CNS accumulation.
    final tight = const PlanEngine(
      config: PlanEngineConfig(pscrRatio: 100),
    ).compute(_pscrPlan(domain.PlanMode.pscr));
    final loose = const PlanEngine(
      config: PlanEngineConfig(pscrRatio: 300),
    ).compute(_pscrPlan(domain.PlanMode.pscr));
    expect(loose.cnsEnd, greaterThan(tight.cnsEnd));
  });

  test('a pSCR plan surfaces a hypoxic-loop warning that OC does not', () {
    const engine = PlanEngine();
    final pscr = engine.compute(_pscrPlan(domain.PlanMode.pscr));
    final oc = engine.compute(_pscrPlan(domain.PlanMode.oc));

    // On EAN32 the pSCR loop O2 falls below the hypoxia threshold near the
    // surface (the fixed metabolic drop exceeds the supply ppO2), so the
    // mode-aware hypoxia check fires. Open circuit on the same gas does not.
    expect(pscr.issues.any((i) => i.type == PlanIssueType.hypoxicGas), isTrue);
    expect(oc.issues.any((i) => i.type == PlanIssueType.hypoxicGas), isFalse);
  });

  test('the SCR loop uses the configured metabolic O2 consumption', () {
    final plan = _plan(domain.PlanMode.scr);
    final lean = const PlanEngine(
      config: PlanEngineConfig(scrVo2Lpm: 0.8),
    ).compute(plan);
    final hungry = const PlanEngine(
      config: PlanEngineConfig(scrVo2Lpm: 1.8),
    ).compute(plan);
    // Less O2 consumed leaves a richer loop: more oxygen exposure.
    expect(lean.cnsEnd, greaterThan(hungry.cnsEnd));
    expect(const PlanEngineConfig().scrVo2Lpm, 1.3);
  });
}

const _ean32 = GasMix(o2: 32);
const _ean32Tank = DiveTank(
  id: 'tank-32',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _ean32,
);

domain.DivePlan _pscrPlan(domain.PlanMode mode) => domain.DivePlan(
  id: 'plan-pscr',
  name: 'pSCR test',
  gfLow: 30,
  gfHigh: 70,
  mode: mode,
  segments: [
    PlanSegment.travel(
      id: 'seg-1',
      fromDepth: 0,
      targetDepth: 30,
      tankId: 'tank-32',
      gasMix: _ean32,
      order: 0,
      ratePerMinute: 18.0,
    ),
    PlanSegment.hold(
      id: 'seg-2',
      depth: 30,
      durationMinutes: 20,
      tankId: 'tank-32',
      gasMix: _ean32,
      order: 1,
    ),
  ],
  tanks: const [_ean32Tank],
  createdAt: DateTime(2026, 7, 17),
  updatedAt: DateTime(2026, 7, 17),
);
