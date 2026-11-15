import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/tide/entities/tide_prediction.dart';

/// Mini tide chart for compact displays (e.g., list items, previews).
class TideChartMini extends StatelessWidget {
  /// Tide predictions to plot.
  final List<TidePrediction> predictions;

  /// Height of the mini chart.
  final double height;

  /// Color of the tide curve.
  final Color? color;

  const TideChartMini({
    super.key,
    required this.predictions,
    this.height = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (predictions.isEmpty) {
      return SizedBox(height: height);
    }

    final chartColor = color ?? Theme.of(context).colorScheme.primary;

    // Calculate bounds
    final heights = predictions.map((p) => p.heightMeters);
    final minHeight = heights.reduce(math.min);
    final maxHeight = heights.reduce(math.max);
    final heightRange = maxHeight - minHeight;
    final paddedMinHeight = minHeight - (heightRange * 0.1);
    final paddedMaxHeight = maxHeight + (heightRange * 0.1);

    final minTime = predictions.first.time;
    double timeToX(DateTime time) {
      return time.difference(minTime).inMinutes / 60.0;
    }

    final maxX = timeToX(predictions.last.time);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: paddedMinHeight,
          maxY: paddedMaxHeight,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: predictions
                  .map((p) => FlSpot(timeToX(p.time), p.heightMeters))
                  .toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: chartColor,
              barWidth: 1.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: chartColor.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
