import 'package:flutter/foundation.dart';

import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

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

  final baseMinutes = {
    for (final m in series.stopLabels) _depthKey(m.depth): minutes(m),
  };
  return [
    for (final m in preview.stopLabels)
      switch (baseMinutes[_depthKey(m.depth)]) {
        null => PlanStopTag(marker: m, label: label(m), isNew: true),
        final before => PlanStopTag(
          marker: m,
          label: label(m),
          change: _change(minutes(m) - before),
        ),
      },
  ];
}

int _depthKey(double meters) => (meters * 10).round();

String? _change(int delta) => switch (delta) {
  0 => null,
  > 0 => '+$delta',
  _ => '−${-delta}',
};
