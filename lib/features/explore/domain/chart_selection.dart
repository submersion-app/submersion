import 'package:submersion/features/explore/domain/query_model.dart';

enum ChartKind {
  divesOverTime,
  depthTrend,
  waterTempTrend,
  bottomTimeTrend,
  sacTrend,
  entityCounts,

  /// A non-dive subject's one chart: dives in the scope per result row.
  subjectCounts;

  /// Whether a clause on a field can ask for this chart. Exhaustive, so a
  /// new kind must say which it is; trends draw in declaration order.
  bool get isTrend => switch (this) {
    divesOverTime || entityCounts || subjectCounts => false,
    depthTrend || waterTempTrend || bottomTimeTrend || sacTrend => true,
  };
}

class ChartRequest {
  final ChartKind kind;
  final MentionKind? entityKind;
  const ChartRequest(this.kind, {this.entityKind});

  @override
  bool operator ==(Object other) =>
      other is ChartRequest &&
      other.kind == kind &&
      other.entityKind == entityKind;

  @override
  int get hashCode => Object.hash(kind, entityKind);
}

const int kMaxExploreCharts = 3;

/// The kinds a count chart can be drawn for, each backed by a ranking query
/// in exploreChartDataProvider. A tag, trip or computer has none, so a chart
/// titled for it would have been filled with site counts.
const Set<MentionKind> kRankedEntityKinds = {
  MentionKind.site,
  MentionKind.place,
  MentionKind.species,
  MentionKind.buddy,
  MentionKind.center,
  MentionKind.gear,
};

/// Rule-based chart choice: the model never picks charts. [trends] are the
/// trend kinds of the clauses said (each field's `trend`), drawn once each
/// in [ChartKind] order.
List<ChartRequest> selectCharts({
  required Iterable<ChartKind> trends,
  required Map<MentionKind, int> resolvedEntityCounts,
}) {
  final out = <ChartRequest>[const ChartRequest(ChartKind.divesOverTime)];
  final said = trends.toSet();
  for (final kind in ChartKind.values) {
    if (kind.isTrend && said.contains(kind)) out.add(ChartRequest(kind));
  }
  // Sites and places both draw dive counts per site: one chart, not two
  // identical ones under different titles.
  var siteCounts = false;
  for (final kind in MentionKind.values) {
    if ((resolvedEntityCounts[kind] ?? 0) <= 1) continue;
    if (!kRankedEntityKinds.contains(kind)) continue;
    if (kind == MentionKind.site || kind == MentionKind.place) {
      if (siteCounts) continue;
      siteCounts = true;
    }
    out.add(ChartRequest(ChartKind.entityCounts, entityKind: kind));
  }
  return out.take(kMaxExploreCharts).toList();
}
