import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _ean50 = GasMix(o2: 50);

domain.DivePlan _plan({
  double? backStartPressure = 200,
  double backVolume = 11.1,
  domain.TurnPressureRule? turnRule = domain.TurnPressureRule.thirds,
  domain.PlanMode mode = domain.PlanMode.oc,
}) {
  final back = DiveTank(
    id: 'back',
    volume: backVolume,
    startPressure: backStartPressure,
    gasMix: _air,
    role: TankRole.backGas,
  );
  const deco = DiveTank(
    id: 'deco',
    volume: 7.0,
    startPressure: 200,
    gasMix: _ean50,
    role: TankRole.deco,
  );
  return domain.DivePlan(
    id: 'plan',
    name: 'Gas limit gaps',
    mode: mode,
    turnPressureRule: turnRule,
    tanks: [back, deco],
    segments: [
      PlanSegment.travel(
        id: 'down',
        fromDepth: 0,
        targetDepth: 30,
        tankId: 'back',
        gasMix: _air,
        order: 0,
        ratePerMinute: 18,
      ),
      PlanSegment.hold(
        id: 'bottom',
        depth: 30,
        durationMinutes: 20,
        tankId: 'back',
        gasMix: _air,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 10, 23),
    updatedAt: DateTime(2026, 10, 23),
  );
}

PlanTankUsage _usage(PlanOutcome outcome, String tankId) =>
    outcome.tankUsages.firstWhere((u) => u.tankId == tankId);

/// The results and the slate say why a back gas has no turn pressure or
/// minimum gas instead of leaving the figure blank (#3603), so the engine
/// reports the missing input alongside each null.
void main() {
  const engine = PlanEngine();

  test('a back gas with a start pressure and a rule has no gaps', () {
    final back = _usage(engine.compute(_plan()), 'back');
    expect(back.turnPressureBar, isNotNull);
    expect(back.minGasBar, isNotNull);
    expect(back.turnPressureGap, isNull);
    expect(back.minGasGap, isNull);
  });

  test('no turn rule names the missing rule, min gas still computes', () {
    final back = _usage(engine.compute(_plan(turnRule: null)), 'back');
    expect(back.turnPressureBar, isNull);
    expect(back.turnPressureGap, PlanGasLimitGap.noTurnRule);
    expect(back.minGasBar, isNotNull);
    expect(back.minGasGap, isNull);
  });

  test('an explicit None rule is reported the same way', () {
    final back = _usage(
      engine.compute(_plan(turnRule: domain.TurnPressureRule.off)),
      'back',
    );
    expect(back.turnPressureGap, PlanGasLimitGap.noTurnRule);
  });

  test('the diver default rule fills an unset plan rule', () {
    const withDefault = PlanEngine(
      config: PlanEngineConfig(
        turnPressureRule: domain.TurnPressureRule.halves,
      ),
    );
    final back = _usage(withDefault.compute(_plan(turnRule: null)), 'back');
    expect(back.turnPressureBar, isNotNull);
    expect(back.turnPressureGap, isNull);
  });

  test('no start pressure names it for both figures', () {
    final back = _usage(engine.compute(_plan(backStartPressure: null)), 'back');
    expect(back.turnPressureBar, isNull);
    expect(back.minGasBar, isNull);
    expect(back.turnPressureGap, PlanGasLimitGap.noStartPressure);
    expect(back.minGasGap, PlanGasLimitGap.noStartPressure);
  });

  test('no rule outranks no start pressure for the turn figure', () {
    // A start pressure alone would still leave turn blank, so the rule is
    // the input the diver has to supply first.
    final back = _usage(
      engine.compute(_plan(backStartPressure: null, turnRule: null)),
      'back',
    );
    expect(back.turnPressureGap, PlanGasLimitGap.noTurnRule);
    expect(back.minGasGap, PlanGasLimitGap.noStartPressure);
  });

  test('a zero-litre back gas names the missing size for min gas', () {
    final back = _usage(engine.compute(_plan(backVolume: 0)), 'back');
    expect(back.minGasBar, isNull);
    expect(back.minGasGap, PlanGasLimitGap.noVolume);
  });

  test('a deco cylinder reports no gap: the figures are back-gas only', () {
    final deco = _usage(engine.compute(_plan(turnRule: null)), 'deco');
    expect(deco.turnPressureBar, isNull);
    expect(deco.minGasBar, isNull);
    expect(deco.turnPressureGap, isNull);
    expect(deco.minGasGap, isNull);
  });
}
