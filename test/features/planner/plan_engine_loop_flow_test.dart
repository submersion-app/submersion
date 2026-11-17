import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/services/plan_engine_settings.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The planner's semi-closed loop flow (issue #4660): a plan's own SCR
/// injection rate and VO2, and pSCR VO2, resolved against the diver's
/// Settings, reach the engine's breathing models.
const _ean50 = GasMix(o2: 50);
const _ean32 = GasMix(o2: 32);

domain.DivePlan _plan(
  domain.PlanMode mode,
  GasMix gas, {
  double? scrInjectionRate,
  double? scrVo2,
  double? pscrVo2,
  double? sacBottom,
}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Loop flow',
  gfLow: 40,
  gfHigh: 80,
  mode: mode,
  scrInjectionRate: scrInjectionRate,
  scrVo2: scrVo2,
  pscrVo2: pscrVo2,
  sacBottom: sacBottom,
  tanks: [
    DiveTank(
      id: 'tank-1',
      volume: 7,
      startPressure: 200,
      gasMix: gas,
      role: TankRole.diluent,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'seg-1',
      fromDepth: 0,
      targetDepth: 18,
      tankId: 'tank-1',
      gasMix: gas,
      order: 0,
      ratePerMinute: 18.0,
    ),
    PlanSegment.hold(
      id: 'seg-2',
      depth: 18,
      durationMinutes: 45,
      tankId: 'tank-1',
      gasMix: gas,
      order: 1,
    ),
  ],
  createdAt: DateTime(2026, 11, 17),
  updatedAt: DateTime(2026, 11, 17),
);

void main() {
  const settingsConfig = PlanEngineConfig();

  test('an SCR plan breathes the CMF loop for the entered rate and VO2', () {
    final plan = _plan(
      domain.PlanMode.scr,
      _ean50,
      scrInjectionRate: 7.5,
      scrVo2: 2.0,
    );
    final resolved = settingsConfig.resolvedFor(plan);
    final breathing = breathingFor(plan, _ean50, 18, config: resolved);

    final loopFO2 = ScrCalculator.calculateCmfSteadyStateFo2(
      injectionRateLpm: 7.5,
      supplyO2Percent: 50,
      vo2: 2.0,
    )!;
    expect(loopFO2, closeTo(0.318, 0.001));
    final expected = OpenCircuit(fO2: loopFO2).inspiredAt(2.8);
    final actual = breathing.inspiredAt(2.8);
    expect(actual.pO2, closeTo(expected.pO2, 1e-9));
    expect(actual.pN2, closeTo(expected.pN2, 1e-9));
  });

  test('supply gas is charged at the entered injection rate', () {
    final resolved = settingsConfig.resolvedFor(
      _plan(domain.PlanMode.scr, _ean50, scrInjectionRate: 7.5),
    );
    expect(
      resolved.cylinderLiters(
        domain.PlanMode.scr,
        sac: 15,
        minutes: 10,
        ambientBar: 4,
      ),
      75.0,
    );
  });

  test('a plan value wins and an unset one follows the diver', () {
    const diver = PlanEngineConfig(
      scrInjectionRateLpm: 9,
      scrVo2Lpm: 1.5,
      pscrVo2Lpm: 0.8,
    );
    final own = diver.resolvedFor(
      _plan(
        domain.PlanMode.scr,
        _ean50,
        scrInjectionRate: 7.5,
        scrVo2: 2.0,
        pscrVo2: 1.1,
      ),
    );
    expect(own.scrInjectionRateLpm, 7.5);
    expect(own.scrVo2Lpm, 2.0);
    expect(own.pscrVo2Lpm, 1.1);

    final follows = diver.resolvedFor(_plan(domain.PlanMode.scr, _ean50));
    expect(follows.scrInjectionRateLpm, 9);
    expect(follows.scrVo2Lpm, 1.5);
    expect(follows.pscrVo2Lpm, 0.8);
  });

  test('an SCR plan with nothing entered computes as it did before', () {
    final plan = _plan(domain.PlanMode.scr, _ean50);
    final before = const PlanEngine(
      config: PlanEngineConfig(scrInjectionRateLpm: 12, scrVo2Lpm: 1.3),
    ).compute(plan);
    final now = PlanEngine(
      config: planEngineConfigFromSettings(const AppSettings()),
    ).compute(plan);
    expect(now.runtimeSeconds, before.runtimeSeconds);
    expect(now.ndlAtBottom, before.ndlAtBottom);
    expect(now.cnsEnd, before.cnsEnd);
    expect(now.tankUsages.map((u) => u.litersUsed), [
      for (final u in before.tankUsages) u.litersUsed,
    ]);
  });

  test('pSCR drop uses the entered VO2 and the plan bottom SAC', () {
    final plan = _plan(
      domain.PlanMode.pscr,
      _ean32,
      pscrVo2: 1.0,
      sacBottom: 25,
    );
    final resolved = settingsConfig.resolvedFor(plan);
    final breathing = breathingFor(plan, _ean32, 18, config: resolved);

    expect(breathing, isA<PassiveScr>());
    final expected = PassiveScr(
      supplyFO2: 0.32,
      o2ConsumptionMlMin: 1000,
      sacMlMin: 25000,
      pscrRatio: resolved.pscrRatio,
    );
    expect(
      (breathing as PassiveScr).o2DropBar,
      closeTo(expected.o2DropBar, 1e-12),
    );
  });

  test('pSCR with nothing entered uses the diver bottom SAC', () {
    final plan = _plan(domain.PlanMode.pscr, _ean32);
    final resolved = const PlanEngineConfig(sacBottom: 15).resolvedFor(plan);
    final breathing =
        breathingFor(plan, _ean32, 18, config: resolved) as PassiveScr;
    expect(breathing.o2ConsumptionMlMin, 720);
    expect(breathing.sacMlMin, 15000);
  });
}
