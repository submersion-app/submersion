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

  /// Whether the row lists its dives. A single dive that follows a logged
  /// dive is saved as a series, but reads as the one plan it is.
  bool get showsDives => dives.length > 1;

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
///
/// A series' dives are looked up in [all] when given, so a row for a series
/// only partly in [plans] (a search hit) still lists every dive; the row's
/// [SavedPlanRow.plan] is then the first of them in [plans].
List<SavedPlanRow> collapseSeries(
  List<DivePlanSummary> plans, {
  List<DivePlanSummary>? all,
}) {
  final bySeries = <String, List<DivePlanSummary>>{};
  for (final plan in all ?? plans) {
    if (plan.seriesId case final id?) {
      bySeries.putIfAbsent(id, () => []).add(plan);
    }
  }
  for (final dives in bySeries.values) {
    // Ties (a dive added at the same place on two devices) break by id, as
    // the planner opens them.
    dives.sort((a, b) {
      final byIndex = (a.seriesIndex ?? 0).compareTo(b.seriesIndex ?? 0);
      return byIndex != 0 ? byIndex : a.id.compareTo(b.id);
    });
  }

  final seen = <String>{};
  return [
    for (final plan in plans)
      if (plan.seriesId == null)
        SavedPlanRow(plan: plan, dives: [plan])
      else if (seen.add(plan.seriesId!))
        SavedPlanRow(
          plan: all == null ? bySeries[plan.seriesId]!.first : plan,
          dives: bySeries[plan.seriesId] ?? [plan],
        ),
  ];
}
