import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/dive.dart';

/// Interactive dive profile chart showing depth over time
class DiveProfileChart extends StatefulWidget {
  final List<DiveProfilePoint> profile;
  final Duration? diveDuration;
  final double? maxDepth;
  final bool showTemperature;
  final bool showPressure;

  const DiveProfileChart({
    super.key,
    required this.profile,
    this.diveDuration,
    this.maxDepth,
    this.showTemperature = true,
    this.showPressure = false,
  });

  @override
  State<DiveProfileChart> createState() => _DiveProfileChartState();
}

class _DiveProfileChartState extends State<DiveProfileChart> {
  bool _showTemperature = true;

  @override
  void initState() {
    super.initState();
    _showTemperature = widget.showTemperature;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile.isEmpty) {
      return _buildEmptyState(context);
    }

    final hasTemperatureData = widget.profile.any((p) => p.temperature != null);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart header with toggle
        if (hasTemperatureData)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _buildLegendItem(
                  context,
                  color: colorScheme.primary,
                  label: 'Depth',
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => setState(() => _showTemperature = !_showTemperature),
                  child: Row(
                    children: [
                      Icon(
                        _showTemperature ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 18,
                        color: colorScheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      _buildLegendItem(
                        context,
                        color: colorScheme.tertiary,
                        label: 'Temperature',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // The chart
        SizedBox(
          height: 200,
          child: _buildChart(context, hasTemperatureData),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No dive profile data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, {required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, bool hasTemperatureData) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate bounds
    final maxTime = widget.profile.map((p) => p.timestamp).reduce(math.max).toDouble();
    final maxDepthValue = widget.profile.map((p) => p.depth).reduce(math.max);
    final chartMaxDepth = (widget.maxDepth ?? maxDepthValue) * 1.1; // Add 10% padding

    // Temperature bounds (if showing)
    double? minTemp, maxTemp;
    if (_showTemperature && hasTemperatureData) {
      final temps = widget.profile.where((p) => p.temperature != null).map((p) => p.temperature!);
      if (temps.isNotEmpty) {
        minTemp = temps.reduce(math.min) - 1;
        maxTemp = temps.reduce(math.max) + 1;
      }
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxTime,
        minY: -chartMaxDepth, // Inverted: negative depth at bottom
        maxY: 0, // Surface (0m) at top
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: _calculateDepthInterval(chartMaxDepth),
          verticalInterval: _calculateTimeInterval(maxTime),
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
              'Depth (m)',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _calculateDepthInterval(chartMaxDepth),
              getTitlesWidget: (value, meta) {
                // Show positive depth values (negate the negative axis values)
                return Text(
                  '${(-value).toInt()}',
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              'Time (min)',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _calculateTimeInterval(maxTime),
              getTitlesWidget: (value, meta) {
                final minutes = (value / 60).round();
                return Text(
                  '$minutes',
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: _showTemperature && hasTemperatureData && minTemp != null,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (minTemp == null || maxTemp == null) return const SizedBox();
                // Map from inverted depth axis to temperature
                final temp = _mapDepthToTemp(-value, chartMaxDepth, minTemp, maxTemp);
                if (temp < minTemp || temp > maxTemp) return const SizedBox();
                return Text(
                  '${temp.toStringAsFixed(0)}°',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.tertiary,
                      ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        lineBarsData: [
          // Depth line
          _buildDepthLine(colorScheme),

          // Temperature line (if showing)
          if (_showTemperature && hasTemperatureData && minTemp != null && maxTemp != null)
            _buildTemperatureLine(colorScheme, chartMaxDepth, minTemp, maxTemp),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => colorScheme.inverseSurface,
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isDepth = spot.barIndex == 0;
                final point = widget.profile[spot.spotIndex];

                if (isDepth) {
                  final minutes = point.timestamp ~/ 60;
                  final seconds = point.timestamp % 60;
                  return LineTooltipItem(
                    '${point.depth.toStringAsFixed(1)}m\n$minutes:${seconds.toString().padLeft(2, '0')}',
                    TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                } else {
                  return LineTooltipItem(
                    '${point.temperature?.toStringAsFixed(1)}°C',
                    TextStyle(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildDepthLine(ColorScheme colorScheme) {
    return LineChartBarData(
      spots: widget.profile
          .map((p) => FlSpot(p.timestamp.toDouble(), -p.depth)) // Negate depth for inverted axis
          .toList(),
      isCurved: true,
      curveSmoothness: 0.2,
      color: colorScheme.primary,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withValues(alpha: 0.05),
            colorScheme.primary.withValues(alpha: 0.3),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildTemperatureLine(
    ColorScheme colorScheme,
    double chartMaxDepth,
    double minTemp,
    double maxTemp,
  ) {
    return LineChartBarData(
      spots: widget.profile
          .where((p) => p.temperature != null)
          .map((p) => FlSpot(
                p.timestamp.toDouble(),
                -_mapTempToDepth(p.temperature!, chartMaxDepth, minTemp, maxTemp), // Negate for inverted axis
              ))
          .toList(),
      isCurved: true,
      curveSmoothness: 0.2,
      color: colorScheme.tertiary,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [5, 3],
    );
  }

  // Map temperature value to depth axis for overlay
  double _mapTempToDepth(double temp, double maxDepth, double minTemp, double maxTemp) {
    final normalized = (temp - minTemp) / (maxTemp - minTemp);
    return maxDepth * (1 - normalized); // Higher temp maps to shallower depth
  }

  // Map depth axis value back to temperature for right axis labels
  double _mapDepthToTemp(double depthAxisValue, double maxDepth, double minTemp, double maxTemp) {
    final normalized = 1 - (depthAxisValue / maxDepth);
    return minTemp + (normalized * (maxTemp - minTemp));
  }

  double _calculateDepthInterval(double maxDepth) {
    if (maxDepth <= 10) return 2;
    if (maxDepth <= 20) return 5;
    if (maxDepth <= 50) return 10;
    return 20;
  }

  double _calculateTimeInterval(double maxTime) {
    final minutes = maxTime / 60;
    if (minutes <= 10) return 60; // 1 min intervals
    if (minutes <= 30) return 300; // 5 min intervals
    if (minutes <= 60) return 600; // 10 min intervals
    return 900; // 15 min intervals
  }
}

/// Compact version of the dive profile chart for list previews
class DiveProfileMiniChart extends StatelessWidget {
  final List<DiveProfilePoint> profile;
  final double height;
  final Color? color;

  const DiveProfileMiniChart({
    super.key,
    required this.profile,
    this.height = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (profile.isEmpty) {
      return SizedBox(height: height);
    }

    final chartColor = color ?? Theme.of(context).colorScheme.primary;
    final maxDepth = profile.map((p) => p.depth).reduce(math.max) * 1.1;
    final maxTime = profile.map((p) => p.timestamp).reduce(math.max).toDouble();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxTime,
          minY: -maxDepth, // Inverted: negative depth at bottom
          maxY: 0, // Surface (0m) at top
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: profile
                  .map((p) => FlSpot(p.timestamp.toDouble(), -p.depth)) // Negate for inverted axis
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
