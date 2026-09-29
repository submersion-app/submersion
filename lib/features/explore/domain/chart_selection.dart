import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

enum ChartKind {
  divesOverTime,
  depthTrend,
  waterTempTrend,
  bottomTimeTrend,
  sacTrend,
  entityCounts,
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

/// Rule-based chart choice: the model never picks charts.
List<ChartRequest> selectCharts({
  required List<ExploreDiveField> numericFields,
  required Map<MentionKind, int> resolvedEntityCounts,
}) {
  final out = <ChartRequest>[const ChartRequest(ChartKind.divesOverTime)];
  const trends = {
    ExploreDiveField.depth: ChartKind.depthTrend,
    ExploreDiveField.waterTemp: ChartKind.waterTempTrend,
    ExploreDiveField.bottomTime: ChartKind.bottomTimeTrend,
    ExploreDiveField.sac: ChartKind.sacTrend,
  };
  for (final entry in trends.entries) {
    if (numericFields.contains(entry.key)) out.add(ChartRequest(entry.value));
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
