import 'package:flutter/widgets.dart';

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

  @override
  bool operator ==(Object other) =>
      other is ProfilePlotFrame &&
      other.plotKey == plotKey &&
      other.plotRect == plotRect &&
      other.minSeconds == minSeconds &&
      other.maxSeconds == maxSeconds &&
      other.minDepthMeters == minDepthMeters &&
      other.maxDepthMeters == maxDepthMeters;

  @override
  int get hashCode => Object.hash(
    plotKey,
    plotRect,
    minSeconds,
    maxSeconds,
    minDepthMeters,
    maxDepthMeters,
  );
}
