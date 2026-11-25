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
      other.marker.isGasSwitchOnly == marker.isGasSwitchOnly &&
      other.label == label &&
      other.change == change &&
      other.isNew == isNew;

  @override
  int get hashCode => Object.hash(
    marker.timeSeconds,
    marker.depth,
    marker.durationSeconds,
    marker.isGasSwitchOnly,
    label,
    change,
    isNew,
  );
}

/// The stops the chart tags on its profile. While a contingency is previewed
/// they are its stops, compared with the plan's, as the table and stats then
/// describe the preview. The Bailout view keeps its own: the ghost is a
/// variant of the live plan, not of the bailout picture.
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

/// The stops the phone readouts list under TTS, Deco and CNS: those of the
/// outcome those figures describe, the live plan's or a previewed
/// contingency's against it. In the Bailout view the chart draws the bailout
/// picture, but the figures above the list still describe the plan, so the
/// list does too.
final planReadoutStopTagsProvider = Provider<List<PlanStopTag>>((ref) {
  final units = ref.watch(unitFormatterProvider);
  return planStopTags(
    series: ref.watch(planLiveCanvasSeriesProvider),
    preview: ref.watch(contingencyGhostSeriesProvider),
    formatDepth: (m) => units.formatDepth(m, decimals: 0),
  );
});

/// The whole minutes a stop of [seconds] is shown with: at least one for a
/// stop held at all, as the runtime table prints it, so a short gas switch
/// stop never reads as 0.
int planStopMinutes(int seconds) =>
    seconds > 0 && seconds < 60 ? 1 : seconds ~/ 60;

/// A stop's time as the chart and the readouts show it, with the minute mark
/// the readouts and the runtime table use.
String planStopDurationText(int seconds) => '${planStopMinutes(seconds)}′';

/// The stop tags to draw: the [preview]'s stops when a contingency is
/// previewed, compared with [series], else [series]'s own. Changes come from
/// the whole minutes the tags show, so the numbers on the chart add up.
List<PlanStopTag> planStopTags({
  required PlanCanvasSeries series,
  PlanCanvasSeries? preview,
  required String Function(double meters) formatDepth,
}) {
  int minutes(CanvasMarker m) => planStopMinutes(m.durationSeconds);
  String label(CanvasMarker m) =>
      '${formatDepth(m.depth)} ${planStopDurationText(m.durationSeconds)}';

  if (preview == null) {
    return [
      for (final m in series.stopLabels)
        PlanStopTag(marker: m, label: label(m)),
    ];
  }

  // Stops can share a depth (a gas-switch-only stop and the deco stop after
  // it), and a lost gas drops its switch stop while the deco stop stays, so
  // a stop is compared with the base stop of its own kind at its depth: the
  // n-th switch stop there with the n-th switch stop, the n-th deco stop with
  // the n-th deco stop.
  final baseMinutes = <_StopKey, List<int>>{};
  for (final m in series.stopLabels) {
    (baseMinutes[_keyOf(m)] ??= []).add(minutes(m));
  }
  final seen = <_StopKey, int>{};
  PlanStopTag previewTag(CanvasMarker m) {
    final key = _keyOf(m);
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

typedef _StopKey = ({int depth, bool switchOnly});

_StopKey _keyOf(CanvasMarker m) =>
    (depth: (m.depth * 10).round(), switchOnly: m.isGasSwitchOnly);

String? _change(int delta) => switch (delta) {
  0 => null,
  > 0 => '+$delta',
  _ => '−${-delta}',
};
