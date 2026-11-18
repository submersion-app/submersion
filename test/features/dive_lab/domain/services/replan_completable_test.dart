import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

PlanOutcome _with(List<PlanIssue> issues) => PlanOutcome(
  runtimeSeconds: 1620,
  maxDepth: 30,
  ndlAtBottom: 600,
  ttsAtBottom: 120,
  stops: const [],
  segmentOutcomes: const [],
  tankUsages: const [],
  cnsEnd: 5,
  otuTotal: 10,
  issues: issues,
  endTissue: const BuhlmannState(compartments: []),
  surfacedTissue: const BuhlmannState(compartments: []),
  tissueTimeline: const [],
  ceilingTrace: const [],
);

PlanIssue _critical(PlanIssueType type) => PlanIssue(
  type: type,
  severity: PlanIssueSeverity.critical,
  message: type.name,
);

void main() {
  test('a replan with no critical issue is completable', () {
    expect(isReplanCompletable(_with(const [])), isTrue);
  });

  test('running out of gas is not completable', () {
    expect(
      isReplanCompletable(_with([_critical(PlanIssueType.gasOut)])),
      isFalse,
    );
  });

  // #4475: under the ascent-only minimum still surfaces; the issue is listed.
  test('leaving the bottom under the minimum gas is still completable', () {
    expect(
      isReplanCompletable(
        _with([_critical(PlanIssueType.minGasAscentViolation)]),
      ),
      isTrue,
    );
  });
}
