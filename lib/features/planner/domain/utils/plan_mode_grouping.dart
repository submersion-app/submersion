import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

/// One mode's plans inside the grouped planned-dives list.
class DivePlanModeGroup {
  const DivePlanModeGroup({required this.mode, required this.plans});

  final PlanMode mode;
  final List<DivePlanSummary> plans;
}

/// Groups [plans] by [DivePlanSummary.mode], in [PlanMode]'s declaration
/// order (OC, CCR, SCR, PSCR), not by recency or input order.
///
/// A mode with no plans is left out entirely rather than yielding an empty
/// group; the planned-dives page never shows a heading with nothing under
/// it. Plans keep their relative order within a group, so sort [plans]
/// before grouping, not after.
List<DivePlanModeGroup> groupPlansByMode(List<DivePlanSummary> plans) {
  final byMode = <PlanMode, List<DivePlanSummary>>{};
  for (final plan in plans) {
    (byMode[plan.mode] ??= []).add(plan);
  }
  return [
    for (final mode in PlanMode.values)
      if (byMode[mode] case final group?)
        DivePlanModeGroup(mode: mode, plans: group),
  ];
}
