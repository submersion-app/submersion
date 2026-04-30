import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';

/// Horizontal strip rendered between the dive profile's plot area and its
/// X-axis tick labels, showing which gas was breathed at every point of
/// the dive.
///
/// Used in two modes:
/// - **Embedded** (typical): mounted by [DiveProfileChart] inside a
///   `Positioned` widget that already constrains it to the plot width;
///   pass `leftPadding: 0` and `rightPadding: 0`.
/// - **Standalone**: with default null paddings the strip mirrors
///   [DiveProfileChart.leftAxisSize] / [DiveProfileChart.rightAxisSize]
///   for the available width — the same reservations the chart uses for
///   its y-axis side titles — so blocks line up with the chart's time axis.
///
/// Each [GasUsageSegment] is drawn as a colored block proportional to its
/// duration, with the gas name shown inside when there is enough room.
class GasTimelineStrip extends StatelessWidget {
  final List<GasUsageSegment> segments;
  final int diveDurationSeconds;

  /// Strip height. Matches Subsurface's gas bar (slim — single label line).
  final double height;

  /// Horizontal insets to align with the chart's plot area. When null (the
  /// default), the strip mirrors [DiveProfileChart.leftAxisSize] /
  /// [DiveProfileChart.rightAxisSize] for the available width — the same
  /// reservations the chart uses for its y-axis side titles — so the strip
  /// blocks line up exactly with the chart's time axis.
  final double? leftPadding;
  final double? rightPadding;

  /// When provided, the strip maps segments onto this visible time window
  /// rather than the full dive. Used to keep the strip in sync with the
  /// chart's zoom/pan state.
  final double? visibleMinSeconds;
  final double? visibleMaxSeconds;

  const GasTimelineStrip({
    super.key,
    required this.segments,
    required this.diveDurationSeconds,
    this.height = 22,
    this.leftPadding,
    this.rightPadding,
    this.visibleMinSeconds,
    this.visibleMaxSeconds,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty || diveDurationSeconds <= 0) {
      return const SizedBox.shrink();
    }
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final left =
            leftPadding ?? DiveProfileChart.leftAxisSize(availableWidth);
        final right =
            rightPadding ?? DiveProfileChart.rightAxisSize(availableWidth);
        final usableWidth = (availableWidth - left - right).clamp(
          0.0,
          double.infinity,
        );

        return SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.only(left: left, right: right),
            child: ClipRRect(
              child: SizedBox(
                width: usableWidth,
                height: height,
                child: Stack(
                  children: [
                    for (final segment in segments)
                      _buildSegment(segment, usableWidth, labelStyle),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegment(
    GasUsageSegment segment,
    double usableWidth,
    TextStyle? labelStyle,
  ) {
    final viewMin = visibleMinSeconds ?? 0.0;
    final viewMax = visibleMaxSeconds ?? diveDurationSeconds.toDouble();
    final viewRange = viewMax - viewMin;
    if (viewRange <= 0) return const SizedBox.shrink();
    final startFraction = ((segment.startSeconds - viewMin) / viewRange).clamp(
      0.0,
      1.0,
    );
    final endFraction = ((segment.endSeconds - viewMin) / viewRange).clamp(
      0.0,
      1.0,
    );
    final blockLeft = startFraction * usableWidth;
    final blockWidth = ((endFraction - startFraction) * usableWidth).clamp(
      0.0,
      usableWidth,
    );
    if (blockWidth <= 0) return const SizedBox.shrink();
    final color = GasColors.forGasMix(segment.gasMix);

    return Positioned(
      left: blockLeft,
      top: 0,
      width: blockWidth,
      height: height,
      child: Tooltip(
        message: segment.label,
        waitDuration: const Duration(milliseconds: 400),
        child: Container(
          color: color,
          alignment: Alignment.center,
          child: blockWidth > 36
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    segment.label,
                    style: labelStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
