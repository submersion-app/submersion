import 'package:flutter/foundation.dart';

/// The slice of the depth axis that a secondary-axis metric is painted into.
///
/// Metrics like NDL, ppO2, GF or TTS have no depth of their own: they are
/// normalized to 0..1 and stretched across the depth axis so they can share the
/// depth plot, with the right-hand axis labelling them. The band says which
/// part of the depth axis to stretch them across.
///
/// It must track the *visible* depth window, not the whole dive. The chart
/// zooms both axes together, so at any zoom > 1 the visible window is a slice
/// of the full depth range. A metric anchored to the full range then falls
/// outside that slice and fl_chart clips it away entirely - the line silently
/// disappears until you zoom back out. Anchoring to the visible window keeps
/// every metric on screen (and its axis labels meaningful) at any zoom.
///
/// Depth-valued curves - the depth trace itself, the deco ceiling, MOD, mean
/// depth - must NOT use a band. They are real depths and belong at their real
/// position, so leaving the viewport when you zoom past them is correct.
@immutable
class MetricBand {
  /// Depth (positive, in display units) of the band's top edge.
  final double top;

  /// Height of the band in display depth units.
  ///
  /// Normally > 0, but a profile that never leaves the surface gives a depth
  /// axis of zero height, so treat 0 as reachable: [map] then collapses every
  /// value onto [top] and [unmap] reports the range minimum. Both stay finite,
  /// which is what matters - a NaN here reaches fl_chart's painter.
  final double span;

  const MetricBand({required this.top, required this.span});

  /// The band covering the whole depth axis, used when the chart is not zoomed.
  factory MetricBand.full(double maxDepth) =>
      MetricBand(top: 0, span: maxDepth);

  /// Maps [value] within [minValue]..[maxValue] to a positive depth inside the
  /// band, with [maxValue] at the top. Callers negate the result, because the
  /// chart's depth axis is inverted (surface at y = 0, depth negative).
  double map(double value, double minValue, double maxValue) {
    // Guard a zero-width range: (value - min) / 0 is NaN, which propagates into
    // FlSpot coordinates and crashes fl_chart's touch/tooltip painter with
    // "Offset argument contained a NaN value". Collapse to the band midpoint so
    // a constant series renders as a finite flat line instead.
    final valueSpan = maxValue - minValue;
    if (valueSpan == 0) return top + span * 0.5;
    return mapNormalized((value - minValue) / valueSpan);
  }

  /// Maps an already-normalized [t] (0 at the band's bottom, 1 at its top) to a
  /// positive depth inside the band. For metrics that carry their own fixed
  /// display scale, such as NDL's 0..60 min.
  double mapNormalized(double t) => top + span * (1 - t);

  /// Inverse of [map]: the metric value drawn at positive depth [depth]. Used
  /// to label the right-hand axis, so labels and line share one mapping.
  double unmap(double depth, double minValue, double maxValue) {
    if (span == 0) return minValue;
    final t = 1 - (depth - top) / span;
    return minValue + t * (maxValue - minValue);
  }

  /// Exact, collision-free identity of this band for cache keys.
  ///
  /// The chart folds the band into its bar-cache signatures, because every
  /// band-mapped bar's Y position moves with it. A hash would be wrong there:
  /// two unequal bands sharing a hash bucket would be served each other's
  /// spots, silently reintroducing the off-screen-metric bug this type exists
  /// to fix. Two doubles round-trip exactly through their decimal form, so
  /// distinct bands always produce distinct keys.
  String get cacheKey => '$top:$span';

  @override
  bool operator ==(Object other) =>
      other is MetricBand && other.top == top && other.span == span;

  @override
  int get hashCode => Object.hash(top, span);

  @override
  String toString() => 'MetricBand(top: $top, span: $span)';
}
