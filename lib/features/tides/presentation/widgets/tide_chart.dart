import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';

/// Interactive tide chart showing water height over time.
///
/// Displays:
/// - Continuous tide curve from predictions
/// - High/low tide markers
/// - Current time indicator
/// - Optional "now" marker with current height
///
/// The chart uses the same fl_chart library as [DiveProfileChart] for
/// consistency in visual style and interaction patterns.
///
/// Usage:
/// ```dart
/// TideChart(
///   predictions: tidePredictions,
///   extremes: tideExtremes,
///   now: DateTime.now(),
/// )
/// ```
class TideChart extends StatefulWidget {
  /// Tide predictions to plot as the main curve.
  final List<TidePrediction> predictions;

  /// High/low tide extremes to mark on the chart.
  final List<TideExtreme>? extremes;

  /// Current time for "now" marker. Defaults to DateTime.now().
  final DateTime? now;

  /// Height of the chart widget.
  final double height;

  /// Whether to show the current time marker.
  final bool showNowMarker;

  /// Whether to show extreme markers (high/low tide dots).
  final bool showExtremeMarkers;

  /// Whether to fill the area under the curve.
  final bool showFill;

  /// Callback when a point on the chart is tapped.
  final void Function(TidePrediction? prediction)? onPointSelected;

  const TideChart({
    super.key,
    required this.predictions,
    this.extremes,
    this.now,
    this.height = 200,
    this.showNowMarker = true,
    this.showExtremeMarkers = true,
    this.showFill = true,
    this.onPointSelected,
  });

  @override
  State<TideChart> createState() => _TideChartState();
}

class _TideChartState extends State<TideChart> {
  @override
  Widget build(BuildContext context) {
    if (widget.predictions.isEmpty) {
      return _buildEmptyState(context);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final reference = widget.now ?? DateTime.now();

    // Calculate time range
    final minTime = widget.predictions.first.time;
    final maxTime = widget.predictions.last.time;

    // Calculate height range with padding
    final heights = widget.predictions.map((p) => p.heightMeters);
    final minHeight = heights.reduce(math.min);
    final maxHeight = heights.reduce(math.max);
    final heightRange = maxHeight - minHeight;
    final paddedMinHeight = minHeight - (heightRange * 0.1);
    final paddedMaxHeight = maxHeight + (heightRange * 0.1);

    // Convert DateTime to hours from start for X axis
    double timeToX(DateTime time) {
      return time.difference(minTime).inMinutes / 60.0;
    }

    final maxX = timeToX(maxTime);
    final nowX = timeToX(reference);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildLegend(context),
        ),

        // Chart
        SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: paddedMinHeight,
              maxY: paddedMaxHeight,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: _calculateHeightInterval(heightRange),
                verticalInterval: _calculateTimeInterval(maxX),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (value) => FlLine(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: Text(
                    'Height (m)',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    interval: _calculateHeightInterval(heightRange),
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          value.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: _calculateTimeInterval(maxX),
                    getTitlesWidget: (value, meta) {
                      final time = minTime.add(
                        Duration(minutes: (value * 60).round()),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('HH:mm').format(time.toLocal()),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: _calculateTimeInterval(maxX),
                    getTitlesWidget: (value, meta) {
                      final time = minTime.add(
                        Duration(minutes: (value * 60).round()),
                      );
                      // Show day labels at midnight crossings
                      if (time.hour == 0 && time.minute < 30) {
                        return Text(
                          DateFormat('EEE').format(time.toLocal()),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              lineBarsData: [
                // Main tide curve
                _buildTideCurve(
                  colorScheme,
                  timeToX,
                  paddedMinHeight,
                  paddedMaxHeight,
                ),

                // Extreme markers
                if (widget.showExtremeMarkers && widget.extremes != null)
                  ..._buildExtremeMarkers(timeToX, minTime, maxTime),
              ],
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  // Current time marker
                  if (widget.showNowMarker && nowX >= 0 && nowX <= maxX)
                    VerticalLine(
                      x: nowX,
                      color: colorScheme.primary,
                      strokeWidth: 2,
                      dashArray: [4, 4],
                      label: VerticalLineLabel(
                        show: true,
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(bottom: 4),
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          backgroundColor: colorScheme.primaryContainer
                              .withValues(alpha: 0.9),
                        ),
                        labelResolver: (line) => ' Now ',
                      ),
                    ),
                ],
                horizontalLines: [
                  // Zero line (mean sea level)
                  if (paddedMinHeight < 0 && paddedMaxHeight > 0)
                    HorizontalLine(
                      y: 0,
                      color: colorScheme.outline.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [8, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                        labelResolver: (line) => 'MSL',
                      ),
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (widget.onPointSelected != null) {
                    if (response?.lineBarSpots != null &&
                        response!.lineBarSpots!.isNotEmpty) {
                      final spot = response.lineBarSpots!.first;
                      if (spot.barIndex == 0 &&
                          spot.spotIndex < widget.predictions.length) {
                        widget.onPointSelected!(
                          widget.predictions[spot.spotIndex],
                        );
                      }
                    } else {
                      widget.onPointSelected!(null);
                    }
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (spot) => colorScheme.inverseSurface,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      if (spot.barIndex != 0) return null;

                      final prediction = widget.predictions[spot.spotIndex];
                      final timeStr = DateFormat(
                        'HH:mm',
                      ).format(prediction.time.toLocal());
                      final dateStr = DateFormat(
                        'EEE, MMM d',
                      ).format(prediction.time.toLocal());

                      return LineTooltipItem(
                        '$timeStr\n',
                        TextStyle(
                          color: colorScheme.onInverseSurface.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${prediction.heightMeters.toStringAsFixed(2)}m\n',
                            style: TextStyle(
                              color: colorScheme.onInverseSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: dateStr,
                            style: TextStyle(
                              color: colorScheme.onInverseSurface.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.waves,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No tide data available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem(
          context,
          color: colorScheme.primary,
          label: 'Tide Level',
        ),
        if (widget.showExtremeMarkers) ...[
          _buildLegendItem(
            context,
            color: Colors.red.shade600,
            label: 'High Tide',
          ),
          _buildLegendItem(
            context,
            color: Colors.blue.shade600,
            label: 'Low Tide',
          ),
        ],
        if (widget.showNowMarker)
          _buildLegendItem(
            context,
            color: colorScheme.primary,
            label: 'Now',
            isDashed: true,
          ),
      ],
    );
  }

  Widget _buildLegendItem(
    BuildContext context, {
    required Color color,
    required String label,
    bool isDashed = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDashed)
          Container(
            width: 12,
            height: 2,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: color,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            child: CustomPaint(painter: _DashedLinePainter(color: color)),
          )
        else
          Container(
            width: 12,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  LineChartBarData _buildTideCurve(
    ColorScheme colorScheme,
    double Function(DateTime) timeToX,
    double minY,
    double maxY,
  ) {
    return LineChartBarData(
      spots: widget.predictions
          .map((p) => FlSpot(timeToX(p.time), p.heightMeters))
          .toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: colorScheme.primary,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: widget.showFill
          ? BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.3),
                  colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
            )
          : BarAreaData(show: false),
    );
  }

  List<LineChartBarData> _buildExtremeMarkers(
    double Function(DateTime) timeToX,
    DateTime minTime,
    DateTime maxTime,
  ) {
    if (widget.extremes == null || widget.extremes!.isEmpty) {
      return [];
    }

    // Filter extremes within visible range
    final visibleExtremes = widget.extremes!
        .where((e) => !e.time.isBefore(minTime) && !e.time.isAfter(maxTime))
        .toList();

    return visibleExtremes.map((extreme) {
      final isHigh = extreme.type == TideExtremeType.high;
      final color = isHigh ? Colors.red.shade600 : Colors.blue.shade600;

      return LineChartBarData(
        spots: [FlSpot(timeToX(extreme.time), extreme.heightMeters)],
        isCurved: false,
        color: Colors.transparent,
        barWidth: 0,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) {
            return FlDotCirclePainter(
              radius: 6,
              color: color,
              strokeWidth: 2,
              strokeColor: Colors.white,
            );
          },
        ),
      );
    }).toList();
  }

  double _calculateHeightInterval(double range) {
    if (range <= 0.5) return 0.1;
    if (range <= 1.0) return 0.2;
    if (range <= 2.0) return 0.5;
    if (range <= 5.0) return 1.0;
    return 2.0;
  }

  double _calculateTimeInterval(double maxHours) {
    if (maxHours <= 6) return 1; // 1 hour intervals
    if (maxHours <= 12) return 2; // 2 hour intervals
    if (maxHours <= 24) return 4; // 4 hour intervals
    if (maxHours <= 48) return 6; // 6 hour intervals
    return 12; // 12 hour intervals
  }
}

/// Simple painter for dashed line in legend
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 3.0;
    const dashSpace = 2.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(math.min(startX + dashWidth, size.width), size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
