import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/estimated_profile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_line_builders.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dash pattern that marks an outline as estimated rather than recorded.
const List<int> _estimateDash = [6, 4];

/// An [EstimatedProfile] drawn as a dashed outline with depth and time axes,
/// captioned as an estimate (issue #4112).
///
/// It has no cursor, tooltip, overlays or markers: there are no recorded
/// samples behind it to report on.
class EstimatedProfileChart extends ConsumerWidget {
  const EstimatedProfileChart({
    super.key,
    required this.profile,
    this.height = 180,
  });

  final EstimatedProfile profile;

  /// Height of the plot, axes included; the caption sits below it.
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall;
    final lineColor = colorScheme.onSurfaceVariant;
    final caption = context.l10n.diveLog_estimatedProfile_caption;

    final maxDepth = units.convertDepth(profile.maxDepth);
    final depthInterval = calculateDepthInterval(maxDepth);
    final duration = profile.durationSeconds;
    final timeInterval = calculateTimeInterval(duration);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          image: true,
          label: caption,
          child: ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: duration,
                  minY: -maxDepth * 1.1,
                  maxY: 0,
                  lineTouchData: const LineTouchData(enabled: false),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    horizontalInterval: depthInterval,
                    verticalInterval: timeInterval,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (_) => FlLine(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        context.l10n.diveLog_profile_axisDepth(
                          units.depthSymbol,
                        ),
                        style: labelStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: depthInterval,
                        getTitlesWidget: (value, meta) {
                          final distToMin = (value - meta.min).abs();
                          if (distToMin > 0 &&
                              distToMin < depthInterval * 0.4) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              '${(-value).toInt()}',
                              style: labelStyle,
                              maxLines: 1,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(
                        context.l10n.diveLog_profile_axisTime,
                        style: labelStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: timeInterval,
                        getTitlesWidget: (value, meta) {
                          final distToMax = (meta.max - value).abs();
                          if (distToMax > 0 && distToMax < timeInterval * 0.4) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              '${(value / 60).round()}',
                              style: labelStyle,
                              maxLines: 1,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    _estimatedOutlineBar(
                      profile,
                      units.convertDepth,
                      color: lineColor.withValues(alpha: 0.8),
                      barWidth: 2,
                      fill: lineColor.withValues(alpha: 0.08),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, top: 4),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.info_outline, size: 14, color: lineColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    caption,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: lineColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A faded, dashed [EstimatedProfile] for a dive list card, standing in for
/// the recorded-profile sparkline (issue #4112).
///
/// Depth stays in meters: the sparkline has no axis, so only its shape
/// matters.
class EstimatedProfileMiniChart extends StatelessWidget {
  const EstimatedProfileMiniChart({
    super.key,
    required this.profile,
    this.height = 40,
    this.color,
  });

  final EstimatedProfile profile;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chartColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: RepaintBoundary(
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: profile.durationSeconds,
            minY: -profile.maxDepth * 1.1,
            maxY: 0,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              _estimatedOutlineBar(
                profile,
                (meters) => meters,
                color: chartColor.withValues(alpha: 0.45),
                barWidth: 1,
                dash: const [3, 3],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashed line for [profile], with depth converted by [toDisplay] and
/// drawn downward from the surface at zero.
LineChartBarData _estimatedOutlineBar(
  EstimatedProfile profile,
  double Function(double meters) toDisplay, {
  required Color color,
  required double barWidth,
  Color? fill,
  List<int> dash = _estimateDash,
}) => LineChartBarData(
  spots: [
    for (final point in profile.points)
      FlSpot(point.seconds, -toDisplay(point.depth)),
  ],
  isCurved: false,
  color: color,
  barWidth: barWidth,
  dashArray: dash,
  dotData: const FlDotData(show: false),
  belowBarData: BarAreaData(show: fill != null, color: fill),
);
