import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/surface_interval_providers.dart';

/// Interactive chart showing tissue saturation recovery over time.
/// Displays 16 tissue compartments as colored lines decreasing toward
/// surface saturation levels during the surface interval.
class TissueRecoveryChart extends ConsumerWidget {
  const TissueRecoveryChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final recoveryCurves = ref.watch(siRecoveryCurveProvider);
    final currentInterval = ref.watch(siSurfaceIntervalProvider);
    final minInterval = ref.watch(siMinimumIntervalProvider);
    final leadingCompartment = ref.watch(siLeadingCompartmentProvider);

    if (recoveryCurves.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find min/max loading values for Y-axis range
    double minLoading = double.infinity;
    double maxLoading = 0;
    for (final curve in recoveryCurves) {
      for (final point in curve) {
        if (point.loadingPercent < minLoading) {
          minLoading = point.loadingPercent;
        }
        if (point.loadingPercent > maxLoading) {
          maxLoading = point.loadingPercent;
        }
      }
    }

    // Add padding to Y-axis
    final yPadding = (maxLoading - minLoading) * 0.1;
    final chartMinY = (minLoading - yPadding).clamp(0.0, double.infinity);
    final chartMaxY = maxLoading + yPadding;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.show_chart,
                    color: colorScheme.tertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tissue Recovery',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Showing how each of 16 tissue compartments off-gas during the surface interval',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Surface interval slider
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text('Surface Interval', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _formatInterval(currentInterval),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: currentInterval.toDouble(),
              min: 0,
              max: 240,
              divisions: 48,
              onChanged: (value) {
                ref.read(siSurfaceIntervalProvider.notifier).state = value
                    .round();
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0 min', style: theme.textTheme.bodySmall),
                  Text('4 hours', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Chart
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 240,
                  minY: chartMinY,
                  maxY: chartMaxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: (chartMaxY - chartMinY) / 4,
                    verticalInterval: 60,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.outlineVariant,
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: colorScheme.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(
                        'Surface Interval',
                        style: theme.textTheme.bodySmall,
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 60,
                        getTitlesWidget: (value, meta) {
                          final hours = value ~/ 60;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${hours}h',
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        'Loading %',
                        style: theme.textTheme.bodySmall,
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Generate a line for each compartment
                    ...List.generate(16, (compartmentIdx) {
                      final curve = recoveryCurves[compartmentIdx];
                      final color = Color(
                        compartmentColorValues[compartmentIdx],
                      );
                      final isLeading = compartmentIdx == leadingCompartment;

                      return LineChartBarData(
                        spots: curve.map((point) {
                          return FlSpot(
                            point.minutes.toDouble(),
                            point.loadingPercent,
                          );
                        }).toList(),
                        isCurved: true,
                        curveSmoothness: 0.2,
                        color: color,
                        barWidth: isLeading ? 3 : 1.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                      );
                    }),
                  ],
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      // Current surface interval marker
                      VerticalLine(
                        x: currentInterval.toDouble(),
                        color: colorScheme.primary,
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (line) => 'Now',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Minimum interval marker
                      if (minInterval > 0 && minInterval <= 240)
                        VerticalLine(
                          x: minInterval.toDouble(),
                          color: Colors.green,
                          strokeWidth: 2,
                          dashArray: [8, 4],
                          label: VerticalLineLabel(
                            show: true,
                            alignment: Alignment.topLeft,
                            labelResolver: (line) => 'Min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      maxContentWidth: 200,
                      getTooltipItems: (touchedSpots) {
                        // Show the leading compartment info
                        if (touchedSpots.isEmpty) return [];

                        // Only show a few key compartments to avoid clutter
                        return touchedSpots
                            .where(
                              (spot) =>
                                  spot.barIndex == leadingCompartment ||
                                  spot.barIndex == 0 ||
                                  spot.barIndex == 15,
                            )
                            .map((spot) {
                              final compartmentNum = spot.barIndex + 1;
                              final category = getCompartmentCategory(
                                spot.barIndex,
                              );
                              return LineTooltipItem(
                                'C$compartmentNum ($category): ${spot.y.toStringAsFixed(1)}%',
                                TextStyle(
                                  color: Color(
                                    compartmentColorValues[spot.barIndex],
                                  ),
                                  fontWeight:
                                      spot.barIndex == leadingCompartment
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              );
                            })
                            .toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            _buildLegend(context, leadingCompartment),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, int leadingCompartment) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compartments (by half-time speed)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildLegendItem(
              context: context,
              label: 'Fast (C1-5)',
              color: Color(compartmentColorValues[2]),
            ),
            _buildLegendItem(
              context: context,
              label: 'Medium (C6-10)',
              color: Color(compartmentColorValues[7]),
            ),
            _buildLegendItem(
              context: context,
              label: 'Slow (C11-16)',
              color: Color(compartmentColorValues[12]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: Color(compartmentColorValues[leadingCompartment]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Leading compartment: C${leadingCompartment + 1}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required BuildContext context,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);

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
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  String _formatInterval(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '$mins min';
  }
}
