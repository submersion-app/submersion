import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_grouping.dart';

/// A point on the profile where one or more warnings start (#3738). Each
/// entry in [groups] is one row of the warnings list, so the marker reads
/// exactly as the list does.
class PlanIssueMarker {
  const PlanIssueMarker({required this.runtimeSeconds, required this.groups});

  final int runtimeSeconds;

  /// Most severe first.
  final List<GroupedPlanIssue> groups;

  /// The worst of [groups], which colours the marker.
  PlanIssueSeverity get severity => groups.first.issue.severity;

  /// The list rows this marker stands for.
  Set<PlanIssueKey> get keys => {for (final g in groups) g.key};
}

/// One marker per warnings-list row that happens at a moment in the dive,
/// placed where its earliest issue starts. Rows starting at the same runtime
/// share a marker. A row with no moment, such as a missing deco gas, has
/// none and stays in the list only. In dive order.
List<PlanIssueMarker> planIssueMarkers(List<PlanIssue> issues) {
  final byRuntime = <int, List<GroupedPlanIssue>>{};
  for (final group in groupPlanIssues(issues)) {
    final starts = [
      for (final issue in issues)
        if ((issue.type, issue.severity) == group.key &&
            issue.atRuntime != null)
          issue.atRuntime!,
    ];
    if (starts.isEmpty) continue;
    final first = starts.reduce((a, b) => a < b ? a : b);
    byRuntime[first] = [...?byRuntime[first], group];
  }
  final runtimes = byRuntime.keys.toList()..sort();
  return [
    for (final runtime in runtimes)
      PlanIssueMarker(
        runtimeSeconds: runtime,
        groups: [...byRuntime[runtime]!]
          ..sort(
            (a, b) => b.issue.severity.index.compareTo(a.issue.severity.index),
          ),
      ),
  ];
}
