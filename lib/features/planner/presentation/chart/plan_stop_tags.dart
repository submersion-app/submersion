import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';

/// One stop tag on the chart, and while a contingency is previewed, how its
/// stop compares with the base plan's stop at the same depth.
@immutable
class PlanStopTag {
  final CanvasMarker marker;
  final String label;

  /// Whole minutes gained or lost against the base plan, e.g. '+3'; null
  /// when unchanged, when there is no preview, or for a new stop.
  final String? change;

  /// A stop the base plan does not have.
  final bool isNew;

  const PlanStopTag({
    required this.marker,
    required this.label,
    this.change,
    this.isNew = false,
  });

  @override
  bool operator ==(Object other) =>
      other is PlanStopTag &&
      other.marker.timeSeconds == marker.timeSeconds &&
      other.marker.depth == marker.depth &&
      other.marker.durationSeconds == marker.durationSeconds &&
      other.label == label &&
      other.change == change &&
      other.isNew == isNew;

  @override
  int get hashCode => Object.hash(
    marker.timeSeconds,
    marker.depth,
    marker.durationSeconds,
    label,
    change,
    isNew,
  );
}

/// The stops the chart shows, tagged on the profile or, on a phone, listed
/// in the readouts. While a contingency is previewed they are its stops,
/// compared with the plan's, as the table and stats then describe the
/// preview. The Bailout view keeps its own: the ghost is a variant of the
/// live plan, not of the bailout picture.
final planChartStopTagsProvider = Provider<List<PlanStopTag>>((ref) {
  final series = ref.watch(planCanvasSeriesProvider);
  final showingBailout = ref.watch(
    planChartBailoutProvider.select((c) => c.picture != null),
  );
  final ghost = showingBailout
      ? null
      : ref.watch(contingencyGhostSeriesProvider);
  final units = ref.watch(unitFormatterProvider);
  return planStopTags(
    series: series,
    preview: ghost,
    formatDepth: (m) => units.formatDepth(m, decimals: 0),
  );
});

/// The stop tags to draw: the [preview]'s stops when a contingency is
/// previewed, compared with [series], else [series]'s own. Changes come from
/// the whole minutes the tags show, so the numbers on the chart add up.
List<PlanStopTag> planStopTags({
  required PlanCanvasSeries series,
  PlanCanvasSeries? preview,
  required String Function(double meters) formatDepth,
}) {
  int minutes(CanvasMarker m) => m.durationSeconds ~/ 60;
  String label(CanvasMarker m) => "${formatDepth(m.depth)} ${minutes(m)}'";

  if (preview == null) {
    return [
      for (final m in series.stopLabels)
        PlanStopTag(marker: m, label: label(m)),
    ];
  }

  // Stops can share a depth (a gas-switch-only stop and the one after it),
  // so they are matched in order: the n-th preview stop at a depth with the
  // n-th base stop there.
  final baseMinutes = <int, List<int>>{};
  for (final m in series.stopLabels) {
    (baseMinutes[_depthKey(m.depth)] ??= []).add(minutes(m));
  }
  final seen = <int, int>{};
  PlanStopTag previewTag(CanvasMarker m) {
    final key = _depthKey(m.depth);
    final index = seen[key] = (seen[key] ?? -1) + 1;
    final before = baseMinutes[key];
    if (before == null || index >= before.length) {
      return PlanStopTag(marker: m, label: label(m), isNew: true);
    }
    return PlanStopTag(
      marker: m,
      label: label(m),
      change: _change(minutes(m) - before[index]),
    );
  }

  return [for (final m in preview.stopLabels) previewTag(m)];
}

int _depthKey(double meters) => (meters * 10).round();

String? _change(int delta) => switch (delta) {
  0 => null,
  > 0 => '+$delta',
  _ => '−${-delta}',
};
