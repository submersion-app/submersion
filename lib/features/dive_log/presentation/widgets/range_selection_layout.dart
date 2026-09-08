import 'package:flutter/foundation.dart';

/// Maps range-selection timestamps to horizontal positions inside the dive
/// profile chart's plot rect, and back.
///
/// The plot rect is the chart area minus the gutters fl_chart reserves for
/// axis names and tick labels, and [visibleMinSeconds]/[visibleMaxSeconds]
/// are the chart's current X window (which narrows as the user zooms). Both
/// come from the chart itself, so a handle drawn through this axis lands on
/// the same pixel as the depth trace at that time (issue #1579).
@immutable
class RangePlotAxis {
  /// Left edge of the plot rect, in chart-local pixels.
  final double plotLeft;

  /// Width of the plot rect in pixels.
  final double plotWidth;

  /// The chart's visible time window in seconds.
  final double visibleMinSeconds;
  final double visibleMaxSeconds;

  const RangePlotAxis({
    required this.plotLeft,
    required this.plotWidth,
    required this.visibleMinSeconds,
    required this.visibleMaxSeconds,
  });

  /// Right edge of the plot rect, in chart-local pixels.
  double get plotRight => plotLeft + plotWidth;

  /// Length of the visible time window in seconds.
  double get visibleSpan => visibleMaxSeconds - visibleMinSeconds;

  /// How many seconds one pixel of horizontal drag covers. Zero for a
  /// degenerate plot rect or time window, so callers never scale by NaN.
  double get secondsPerPixel {
    if (plotWidth <= 0 || visibleSpan <= 0) return 0;
    return visibleSpan / plotWidth;
  }

  /// Whether [seconds] falls inside the visible window. A handle outside it
  /// has no honest position on screen, so it is not drawn.
  bool isVisible(num seconds) =>
      seconds >= visibleMinSeconds && seconds <= visibleMaxSeconds;

  /// Chart-local x for [seconds]. Values outside the visible window map
  /// outside the plot rect; use [clampedXForSeconds] for shading bounds.
  double xForSeconds(num seconds) {
    if (visibleSpan <= 0) return plotLeft;
    return plotLeft + ((seconds - visibleMinSeconds) / visibleSpan) * plotWidth;
  }

  /// [xForSeconds] pinned to the plot rect, for spans (such as the shaded
  /// out-of-range areas) that stay meaningful when one end is off screen.
  double clampedXForSeconds(num seconds) =>
      xForSeconds(seconds).clamp(plotLeft, plotRight);

  /// Seconds at chart-local [x].
  double secondsForX(double x) {
    if (plotWidth <= 0) return visibleMinSeconds;
    return visibleMinSeconds + ((x - plotLeft) / plotWidth) * visibleSpan;
  }
}
