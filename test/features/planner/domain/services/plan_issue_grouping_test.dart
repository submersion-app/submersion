import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_grouping.dart';

PlanIssue _issue(
  PlanIssueType type,
  PlanIssueSeverity severity, {
  double? value,
  double? depth,
  String? segmentId,
}) => PlanIssue(
  type: type,
  severity: severity,
  message: '$type',
  value: value,
  atDepth: depth,
  segmentId: segmentId,
);

void main() {
  test(
    'repeats of the same issue collapse to one row with the worst value',
    () {
      final grouped = groupPlanIssues([
        _issue(
          PlanIssueType.gasDensityCritical,
          PlanIssueSeverity.critical,
          value: 6.7,
          segmentId: 'a',
        ),
        _issue(
          PlanIssueType.gasDensityCritical,
          PlanIssueSeverity.critical,
          value: 7.3,
          segmentId: 'b',
        ),
        _issue(
          PlanIssueType.gasDensityCritical,
          PlanIssueSeverity.critical,
          value: 7.3,
          segmentId: 'c',
        ),
        _issue(
          PlanIssueType.endExceeded,
          PlanIssueSeverity.warning,
          value: 46,
          segmentId: 'a',
        ),
        _issue(
          PlanIssueType.endExceeded,
          PlanIssueSeverity.warning,
          value: 51,
          segmentId: 'b',
        ),
      ]);

      expect(grouped.length, 2);
      expect(grouped[0].issue.type, PlanIssueType.gasDensityCritical);
      expect(grouped[0].issue.value, 7.3);
      expect(grouped[0].count, 3);
      expect(grouped[1].issue.type, PlanIssueType.endExceeded);
      expect(grouped[1].issue.value, 51);
      expect(grouped[1].count, 2);
    },
  );

  test(
    'different severities of one type stay separate, in first-seen order',
    () {
      final grouped = groupPlanIssues([
        _issue(
          PlanIssueType.gasDensityHigh,
          PlanIssueSeverity.warning,
          value: 6.0,
        ),
        _issue(
          PlanIssueType.gasDensityCritical,
          PlanIssueSeverity.critical,
          value: 6.8,
        ),
        _issue(
          PlanIssueType.gasDensityHigh,
          PlanIssueSeverity.warning,
          value: 6.2,
        ),
      ]);
      expect(grouped.map((g) => g.issue.type), [
        PlanIssueType.gasDensityHigh,
        PlanIssueType.gasDensityCritical,
      ]);
      expect(grouped[0].count, 2);
      expect(grouped[0].issue.value, 6.2);
      expect(grouped[1].count, 1);
    },
  );

  test('single issues pass through unchanged', () {
    final only = _issue(PlanIssueType.gasOut, PlanIssueSeverity.critical);
    final grouped = groupPlanIssues([only]);
    expect(grouped.single.issue, same(only));
    expect(grouped.single.count, 1);
  });

  test('empty input yields empty output', () {
    expect(groupPlanIssues(const []), isEmpty);
  });
}
