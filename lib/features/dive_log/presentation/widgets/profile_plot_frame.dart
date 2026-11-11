import 'package:flutter/widgets.dart';

import 'package:submersion/core/ui/chart_viewport.dart';

/// Stroke width of a dive profile chart's depth line. The pinned strip draws
/// its line at the same width, so the hand-over shows one line throughout.
const double kProfileDepthLineWidth = 1;

/// Where a [DiveProfileChart]'s plot sits and what it spans: [plotKey] marks
/// a box laid exactly over the plot, and the ranges are the visible time and
/// depth (depth in meters, whatever unit the axis shows).
///
/// The pinned profile card's chart reports it, so the strip's hand-over
/// starts with its depth line exactly on the chart's (issue #4423).
@immutable
class ProfilePlotFrame {
  const ProfilePlotFrame({
    required this.plotKey,
    required this.plotRect,
    required this.minSeconds,
    required this.maxSeconds,
    required this.minDepthMeters,
    required this.maxDepthMeters,
    this.viewport = ChartViewport.reset,
  });

  final GlobalKey plotKey;

  /// The plot's rect within the chart. Part of the frame so a plot that
  /// moves without its ranges changing (an axis shown or hidden, a resize)
  /// is still reported again.
  final Rect plotRect;
  final double minSeconds;
  final double maxSeconds;
  final double minDepthMeters;
  final double maxDepthMeters;

  /// The zoom window the plot was drawn with: the ranges above are this
  /// window of the whole dive.
  final ChartViewport viewport;

  /// This frame as the plot would be in [other] instead: the same plot, its
  /// ranges the same dive seen through [other].
  ///
  /// The ranges follow from the window in a straight line, the way the chart
  /// works them out, so they need no new layout: the pinned profile hands its
  /// copy of the chart a window and knows what it shows on the same frame.
  ProfilePlotFrame withViewport(ChartViewport other) {
    final spanSeconds = (maxSeconds - minSeconds) * viewport.zoom;
    final fromSeconds = minSeconds - viewport.offsetX * spanSeconds;
    final spanDepth = (maxDepthMeters - minDepthMeters) * viewport.zoom;
    final fromDepth = minDepthMeters - viewport.offsetY * spanDepth;
    final minS = fromSeconds + other.offsetX * spanSeconds;
    final minD = fromDepth + other.offsetY * spanDepth;
    return ProfilePlotFrame(
      plotKey: plotKey,
      plotRect: plotRect,
      minSeconds: minS,
      maxSeconds: minS + spanSeconds / other.zoom,
      minDepthMeters: minD,
      maxDepthMeters: minD + spanDepth / other.zoom,
      viewport: other,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProfilePlotFrame &&
      other.plotKey == plotKey &&
      other.plotRect == plotRect &&
      other.minSeconds == minSeconds &&
      other.maxSeconds == maxSeconds &&
      other.minDepthMeters == minDepthMeters &&
      other.maxDepthMeters == maxDepthMeters &&
      other.viewport.sameWindowAs(viewport);

  @override
  int get hashCode => Object.hash(
    plotKey,
    plotRect,
    minSeconds,
    maxSeconds,
    minDepthMeters,
    maxDepthMeters,
    viewport.zoom,
    viewport.offsetX,
    viewport.offsetY,
  );
}
