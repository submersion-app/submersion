import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/exit_path_evaluator.dart';

PlanOutcome _withIssue(PlanIssueType type) => PlanOutcome(
  runtimeSeconds: 1620,
  maxDepth: 30,
  ndlAtBottom: 600,
  ttsAtBottom: 120,
  stops: const [],
  segmentOutcomes: const [],
  tankUsages: const [],
  cnsEnd: 5,
  otuTotal: 10,
  issues: [
    PlanIssue(
      type: type,
      severity: PlanIssueSeverity.critical,
      message: type.name,
    ),
  ],
  endTissue: const BuhlmannState(compartments: []),
  surfacedTissue: const BuhlmannState(compartments: []),
  tissueTimeline: const [],
  ceilingTrace: const [],
);

void main() {
  group('ExitPathEvaluator.breaksCriticalLimit', () {
    test('a critical ppO2 limit makes the exit not diveable', () {
      expect(
        ExitPathEvaluator.breaksCriticalLimit(
          _withIssue(PlanIssueType.ppO2Critical),
        ),
        isTrue,
      );
    });

    test('gas running out is left to the per-diver gas check', () {
      expect(
        ExitPathEvaluator.breaksCriticalLimit(_withIssue(PlanIssueType.gasOut)),
        isFalse,
      );
    });

    // #4475: the plan's single-SAC minimum gas is not the team's gas; each
    // diver's own exit is sized by this evaluator.
    test('leaving the bottom short of an ascent is left to the per-diver '
        'gas check', () {
      expect(
        ExitPathEvaluator.breaksCriticalLimit(
          _withIssue(PlanIssueType.minGasAscentViolation),
        ),
        isFalse,
      );
    });
  });
}
