import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

/// One row of the saved plans list (issue #3565): an ordinary plan, or a
/// whole series with its dives in order.
class SavedPlanRow {
  /// The plan, or the first dive of the series.
  final DivePlanSummary plan;

  /// Every dive of the series in order; just [plan] for an ordinary plan.
  final List<DivePlanSummary> dives;

  const SavedPlanRow({required this.plan, required this.dives});

  bool get isSeries => plan.seriesId != null;

  /// Whether this is several dives. A single dive that follows a logged dive
  /// is saved as a series, but reads as the one plan it is.
  bool get hasSeveralDives => dives.length > 1;

  /// Whether the row lists its dives: when it has several, or its one dive is
  /// in the log, which the line links to.
  bool get showsDives => hasSeveralDives || dives.single.linkedDiveId != null;

  /// The deepest dive of the row, or null when none has a summary.
  double? get maxDepth {
    double? deepest;
    for (final dive in dives) {
      final depth = dive.maxDepth;
      if (depth != null && (deepest == null || depth > deepest)) {
        deepest = depth;
      }
    }
    return deepest;
  }

  /// The dives' runtimes added up, or null when none has a summary. Surface
  /// intervals are left out.
  int? get runtimeSeconds {
    int? total;
    for (final dive in dives) {
      final runtime = dive.runtimeSeconds;
      if (runtime != null) total = (total ?? 0) + runtime;
    }
    return total;
  }
}

/// [plans] with each series collapsed to one row, where its first listed dive
/// came. Rows keep the order of [plans], so a sort still decides them.
List<SavedPlanRow> collapseSeries(List<DivePlanSummary> plans) {
  final bySeries = <String, List<DivePlanSummary>>{};
  for (final plan in plans) {
    if (plan.seriesId case final id?) {
      bySeries.putIfAbsent(id, () => []).add(plan);
    }
  }
  for (final dives in bySeries.values) {
    dives.sort((a, b) => (a.seriesIndex ?? 0).compareTo(b.seriesIndex ?? 0));
  }

  final seen = <String>{};
  return [
    for (final plan in plans)
      if (plan.seriesId == null)
        SavedPlanRow(plan: plan, dives: [plan])
      else if (seen.add(plan.seriesId!))
        SavedPlanRow(
          plan: bySeries[plan.seriesId]!.first,
          dives: bySeries[plan.seriesId]!,
        ),
  ];
}
