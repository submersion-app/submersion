import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

// Issue #4475: problem-solving time and the ascent were each paid for twice
// when the planner checked minimum gas. Gas used is now the dive itself, the
// problem-solving gas is its own figure, and minimum gas is read against the
// cylinder as the diver leaves the bottom.

const _air = GasMix(o2: 21);

/// EN13319, so ambient pressure is the hand-calculation 1 bar per 10 m.
final _salinity = DiveEnvironment.salinityPptFromDensity(
  DiveEnvironment.en13319Density,
);

domain.DivePlan _plan({
  double startPressure = 200,
  int problemSolvingMinutes = 2,
  double depth = 30,
  int minutes = 20,
}) => domain.DivePlan(
  id: 'plan-4475',
  name: 'Minimum gas at the bottom',
  gfLow: 40,
  gfHigh: 80,
  sacBottom: 15,
  sacDeco: 15,
  problemSolvingMinutes: problemSolvingMinutes,
  salinityPpt: _salinity,
  tanks: [
    DiveTank(
      id: 'back',
      volume: 12,
      startPressure: startPressure,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: depth,
      tankId: 'back',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: minutes,
      tankId: 'back',
      gasMix: _air,
      order: 1,
    ),
  ],
  createdAt: DateTime(2026, 11, 16),
  updatedAt: DateTime(2026, 11, 16),
);

PlanTankUsage _back(PlanOutcome outcome) =>
    outcome.tankUsages.firstWhere((u) => u.tankId == 'back');

List<PlanIssue> _minGasIssues(PlanOutcome outcome) => [
  for (final issue in outcome.issues)
    if (issue.type == PlanIssueType.minGasViolation ||
        issue.type == PlanIssueType.minGasAscentViolation)
      issue,
];

void main() {
  final env = DiveEnvironment.forConditions(salinityPpt: _salinity);

  group('gas used is the dive itself', () {
    const engine = PlanEngine();

    test('problem-solving time adds nothing to gas used', () {
      final none = _back(engine.compute(_plan(problemSolvingMinutes: 0)));
      final two = _back(engine.compute(_plan(problemSolvingMinutes: 2)));

      expect(two.litersUsed, closeTo(none.litersUsed, 1e-6));
      expect(two.remainingPressure, closeTo(none.remainingPressure!, 1e-6));
    });

    test('problem-solving gas is its own figure on the bottom cylinder', () {
      final usage = _back(engine.compute(_plan()));

      // 2 minutes at 30 m on bottom SAC x the buddy factor: 15 x 2 x 2 x 4.
      final expected = 15.0 * 2.0 * 2 * env.pressureAtDepth(30);
      expect(usage.problemSolvingLiters, closeTo(expected, 1e-6));
      expect(usage.problemSolvingPressure, isNotNull);
      expect(usage.problemSolvingPressure!, greaterThan(0));
    });

    test('no problem-solving time, no problem-solving gas', () {
      final usage = _back(engine.compute(_plan(problemSolvingMinutes: 0)));

      expect(usage.problemSolvingLiters, 0);
      expect(usage.problemSolvingPressure, isNull);
    });
  });

  group('minimum gas is read where the bottom ends', () {
    // Ideal gas, so a bar is exactly 12 liters and the bands can be placed by
    // hand.
    const engine = PlanEngine(
      config: PlanEngineConfig(gasModel: GasModel.ideal),
    );

    test('the bottom-end pressure is the fill less descent and bottom', () {
      final usage = _back(engine.compute(_plan()));

      final descent = 15.0 * (30 / 18) * env.pressureAtDepth(15);
      final bottom = 15.0 * 20 * env.pressureAtDepth(30);
      expect(
        usage.bottomEndPressure,
        closeTo(200 - (descent + bottom) / 12, 1e-6),
      );
      expect(usage.bottomEndPressure!, greaterThan(usage.remainingPressure!));
    });

    test('a shallower level after the bottom is not read as the bottom', () {
      final deepOnly = _back(engine.compute(_plan()));
      final plan = _plan();
      final multiLevel = _back(
        engine.compute(
          plan.copyWith(
            segments: [
              ...plan.segments,
              PlanSegment.travel(
                id: 'up',
                fromDepth: 30,
                targetDepth: 15,
                tankId: 'back',
                gasMix: _air,
                order: 2,
                ratePerMinute: 9,
              ),
              PlanSegment.hold(
                id: 'shallow',
                depth: 15,
                durationMinutes: 20,
                tankId: 'back',
                gasMix: _air,
                order: 3,
              ),
            ],
          ),
        ),
      );

      // Read as the diver leaves 30 m, before the 15 m level is breathed.
      expect(
        multiLevel.bottomEndPressure,
        closeTo(deepOnly.bottomEndPressure!, 1e-6),
      );
      expect(
        multiLevel.remainingPressure!,
        lessThan(deepOnly.remainingPressure!),
      );
    });

    test('the ascent-only minimum is rock bottom less its problem-solving '
        'time', () {
      final usage = _back(engine.compute(_plan()));

      // Stressed SAC 15 x 2.5, shared with a buddy, for 2 minutes at 30 m.
      final problemSolving = 15.0 * 2.5 * 2 * 2 * env.pressureAtDepth(30) / 12;
      expect(
        usage.minGasBar! - usage.minGasAscentBar!,
        closeTo(problemSolving, 1e-6),
      );
    });

    // Where the bottom ends, from a fill high enough to clear every check.
    ({double usedAtBottom, double minGas, double ascentOnly}) probe() {
      final usage = _back(engine.compute(_plan(startPressure: 300)));
      return (
        usedAtBottom: 300 - usage.bottomEndPressure!,
        minGas: usage.minGasBar!,
        ascentOnly: usage.minGasAscentBar!,
      );
    }

    test('enough at the bottom raises nothing, though the tank ends below '
        'rock bottom', () {
      final p = probe();
      final outcome = engine.compute(
        _plan(startPressure: p.usedAtBottom + p.minGas + 5),
      );

      // The ascent has been breathed by the end: rock bottom already holds
      // gas for it, so the end pressure is not what it is checked against.
      expect(_back(outcome).remainingPressure!, lessThan(p.minGas));
      expect(_minGasIssues(outcome), isEmpty);
    });

    test('enough for the ascent but not problem-solving is a warning', () {
      final p = probe();
      final outcome = engine.compute(
        _plan(startPressure: p.usedAtBottom + (p.minGas + p.ascentOnly) / 2),
      );

      final issue = _minGasIssues(outcome).single;
      expect(issue.type, PlanIssueType.minGasViolation);
      expect(issue.severity, PlanIssueSeverity.warning);
      expect(issue.value, closeTo((p.minGas + p.ascentOnly) / 2, 1e-6));
      expect(issue.threshold, closeTo(p.minGas, 1e-6));
      expect(outcome.isDiveable, isTrue);
    });

    test('not enough for the ascent alone is critical', () {
      final p = probe();
      final outcome = engine.compute(
        _plan(startPressure: p.usedAtBottom + p.ascentOnly - 5),
      );

      final issue = _minGasIssues(outcome).single;
      expect(issue.type, PlanIssueType.minGasAscentViolation);
      expect(issue.severity, PlanIssueSeverity.critical);
      expect(issue.value, closeTo(p.ascentOnly - 5, 1e-6));
      expect(issue.threshold, closeTo(p.ascentOnly, 1e-6));
      expect(outcome.isDiveable, isFalse);
    });
  });

  test("the issue's example: 30 m for 20 minutes on a 12 L 200 bar fill "
      'is a warning, not a shortfall twice over', () {
    final outcome = const PlanEngine().compute(_plan());
    final usage = _back(outcome);

    expect(usage.bottomEndPressure!, lessThan(usage.minGasBar!));
    expect(usage.bottomEndPressure!, greaterThan(usage.minGasAscentBar!));
    final issue = _minGasIssues(outcome).single;
    expect(issue.type, PlanIssueType.minGasViolation);
    expect(issue.severity, PlanIssueSeverity.warning);
  });
}
