import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A compact, non-interactive depth-vs-time sparkline for dive profiles.
///
/// Renders a minimal [LineChart] showing the dive's depth curve with a subtle
/// gradient fill. Designed for inline use in lists where a visual "fingerprint"
/// of the dive shape is helpful (e.g. import wizard review step).
///
/// Returns [SizedBox.shrink] when [profile] is empty.
class DiveSparkline extends StatelessWidget {
  /// The profile sample points (timestamp + depth).
  final List<DiveProfilePoint> profile;

  /// Widget width in logical pixels.
  final double width;

  /// Widget height in logical pixels.
  final double height;

  /// Line and fill color. Defaults to [ColorScheme.primary].
  final Color? color;

  const DiveSparkline({
    super.key,
    required this.profile,
    this.width = 80,
    this.height = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (profile.isEmpty) return const SizedBox.shrink();

    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    final samples = downsample(profile);

    // Negate depth so the curve goes downward (divers' convention).
    final spots = samples
        .map((p) => FlSpot(p.timestamp.toDouble(), -p.depth))
        .toList();

    return SizedBox(
      width: width,
      height: height,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          clipData: const FlClipData.all(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: effectiveColor,
              barWidth: 1.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: effectiveColor.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Downsample a profile to at most [maxPoints] using uniform stride.
  ///
  /// Always preserves the first and last points. Returns the original list
  /// unchanged when it contains [maxPoints] or fewer points.
  static List<DiveProfilePoint> downsample(
    List<DiveProfilePoint> points, {
    int maxPoints = 40,
  }) {
    if (points.length <= maxPoints) return points;

    final result = <DiveProfilePoint>[points.first];
    final stride = (points.length - 1) / (maxPoints - 1);

    for (var i = 1; i < maxPoints - 1; i++) {
      result.add(points[(i * stride).round()]);
    }

    result.add(points.last);
    return result;
  }
}
