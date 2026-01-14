import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/providers/provider.dart';
import '../../../dive_log/domain/entities/dive.dart';
import '../providers/dive_planner_providers.dart';

/// Visual chart showing the planned dive profile.
///
/// Displays:
/// - Depth over time graph
/// - Color-coded segments by type
/// - Deco stops visualization
/// - Gas switch markers
class PlanProfileChart extends ConsumerWidget {
  const PlanProfileChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilePoints = ref.watch(planProfilePointsProvider);
    final planState = ref.watch(divePlanNotifierProvider);
    final theme = Theme.of(context);

    if (profilePoints.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.show_chart,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No profile to display',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add segments to see the dive profile',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate axis bounds
    final maxDepth = planState.maxDepth;
    final maxTime = planState.totalTimeSeconds / 60; // in minutes

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with stats
            Row(
              children: [
                Icon(Icons.show_chart, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Dive Profile',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                _StatChip(
                  label: 'Max',
                  value: '${maxDepth.toStringAsFixed(0)}m',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Time',
                  value: '${maxTime.toStringAsFixed(0)}min',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chart
            Expanded(
              child: LineChart(
                _buildChartData(profilePoints, maxDepth, maxTime, theme),
              ),
            ),

            // Legend
            const SizedBox(height: 16),
            _buildLegend(theme),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData(
    List<DiveProfilePoint> points,
    double maxDepth,
    double maxTime,
    ThemeData theme,
  ) {
    // Convert profile points to chart spots
    final spots = points
        .map(
          (p) => FlSpot(
            p.timestamp / 60, // x: time in minutes
            p.depth, // y: depth (positive down)
          ),
        )
        .toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: _calculateInterval(maxDepth),
        verticalInterval: _calculateInterval(maxTime),
        getDrawingHorizontalLine: (value) => FlLine(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          axisNameWidget: Text('Time (min)', style: theme.textTheme.labelSmall),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: _calculateInterval(maxTime),
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toStringAsFixed(0),
                  style: theme.textTheme.labelSmall,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: Text('Depth (m)', style: theme.textTheme.labelSmall),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: _calculateInterval(maxDepth),
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toStringAsFixed(0),
                  style: theme.textTheme.labelSmall,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      minX: 0,
      maxX: maxTime > 0 ? maxTime * 1.05 : 10,
      minY: 0,
      maxY: maxDepth > 0 ? maxDepth * 1.1 : 10,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.7),
            ],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.3),
                theme.colorScheme.primary.withValues(alpha: 0.05),
              ],
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)}m @ ${spot.x.toStringAsFixed(1)}min',
                TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  double _calculateInterval(double maxValue) {
    if (maxValue <= 0) return 5;
    if (maxValue <= 10) return 2;
    if (maxValue <= 20) return 5;
    if (maxValue <= 50) return 10;
    if (maxValue <= 100) return 20;
    return 30;
  }

  Widget _buildLegend(ThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        const _LegendItem(color: Colors.blue, label: 'Descent'),
        _LegendItem(color: theme.colorScheme.primary, label: 'Bottom'),
        const _LegendItem(color: Colors.green, label: 'Ascent'),
        const _LegendItem(color: Colors.orange, label: 'Deco'),
        const _LegendItem(color: Colors.teal, label: 'Safety'),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
