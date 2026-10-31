import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_markers.dart';

PlanIssue _issue(
  PlanIssueType type,
  PlanIssueSeverity severity, {
  int? at,
  double? value,
}) => PlanIssue(
  type: type,
  severity: severity,
  message: '$type',
  atRuntime: at,
  value: value,
);

void main() {
  test('each warning row gets one marker where it first starts', () {
    final markers = planIssueMarkers([
      _issue(
        PlanIssueType.gasDensityHigh,
        PlanIssueSeverity.warning,
        at: 600,
        value: 5.4,
      ),
      _issue(
        PlanIssueType.gasDensityHigh,
        PlanIssueSeverity.warning,
        at: 120,
        value: 5.3,
      ),
    ]);
    expect(markers, hasLength(1));
    expect(markers.single.runtimeSeconds, 120);
    // The text is the list row's: the worst value, two legs.
    expect(markers.single.groups.single.issue.value, 5.4);
    expect(markers.single.groups.single.count, 2);
  });

  test('warnings that start together share one marker, worst first', () {
    final markers = planIssueMarkers([
      _issue(PlanIssueType.endExceeded, PlanIssueSeverity.warning, at: 90),
      _issue(
        PlanIssueType.gasDensityCritical,
        PlanIssueSeverity.critical,
        at: 90,
      ),
    ]);
    expect(markers, hasLength(1));
    expect(markers.single.severity, PlanIssueSeverity.critical);
    expect(markers.single.groups.map((g) => g.issue.type), [
      PlanIssueType.gasDensityCritical,
      PlanIssueType.endExceeded,
    ]);
  });

  test('a warning with no moment gets no marker', () {
    final markers = planIssueMarkers([
      _issue(PlanIssueType.noBailoutCarried, PlanIssueSeverity.alert),
      _issue(PlanIssueType.cnsWarning, PlanIssueSeverity.warning, at: 0),
    ]);
    expect(markers.map((m) => m.groups.single.issue.type), [
      PlanIssueType.cnsWarning,
    ]);
    expect(markers.single.runtimeSeconds, 0);
  });

  test('markers run in dive order', () {
    final markers = planIssueMarkers([
      _issue(PlanIssueType.gasOut, PlanIssueSeverity.critical, at: 1800),
      _issue(PlanIssueType.ppO2High, PlanIssueSeverity.warning, at: 100),
    ]);
    expect(markers.map((m) => m.runtimeSeconds), [100, 1800]);
  });

  test('a marker is keyed by the rows it stands for', () {
    final marker = planIssueMarkers([
      _issue(PlanIssueType.ppO2High, PlanIssueSeverity.warning, at: 100),
    ]).single;
    expect(marker.keys, {(PlanIssueType.ppO2High, PlanIssueSeverity.warning)});
  });
}
