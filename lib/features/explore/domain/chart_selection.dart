import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

enum ChartKind {
  divesOverTime,
  depthTrend,
  waterTempTrend,
  bottomTimeTrend,
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
  };
  for (final entry in trends.entries) {
    if (numericFields.contains(entry.key)) out.add(ChartRequest(entry.value));
  }
  for (final kind in MentionKind.values) {
    if ((resolvedEntityCounts[kind] ?? 0) > 1) {
      out.add(ChartRequest(ChartKind.entityCounts, entityKind: kind));
    }
  }
  return out.take(kMaxExploreCharts).toList();
}
