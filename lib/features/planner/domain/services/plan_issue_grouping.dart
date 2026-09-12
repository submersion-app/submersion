import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// One warning row standing in for every [PlanIssue] of the same type and
/// severity. [issue] is the representative the row is rendered from and
/// [count] how many raw issues it covers.
class GroupedPlanIssue {
  const GroupedPlanIssue({required this.issue, required this.count});

  final PlanIssue issue;
  final int count;
}

/// Collapses issues the engine raised once per segment (gas density, END,
/// ppO2 and so on) into one row per type and severity, keeping the
/// first-seen order and the worst value: the deepest END, the highest
/// density. A diver reads "gas density 7.3 g/L over the hard limit, 4 legs"
/// once instead of scrolling past the same line four times.
List<GroupedPlanIssue> groupPlanIssues(List<PlanIssue> issues) {
  final order = <(PlanIssueType, PlanIssueSeverity)>[];
  final groups = <(PlanIssueType, PlanIssueSeverity), GroupedPlanIssue>{};

  for (final issue in issues) {
    final key = (issue.type, issue.severity);
    final existing = groups[key];
    if (existing == null) {
      order.add(key);
      groups[key] = GroupedPlanIssue(issue: issue, count: 1);
      continue;
    }
    final worse = _isWorse(issue, existing.issue) ? issue : existing.issue;
    groups[key] = GroupedPlanIssue(issue: worse, count: existing.count + 1);
  }

  return [for (final key in order) groups[key]!];
}

bool _isWorse(PlanIssue candidate, PlanIssue current) {
  final a = candidate.value;
  final b = current.value;
  if (a == null) return false;
  if (b == null) return true;
  return a > b;
}
