import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_axis.dart';
import 'package:submersion/l10n/l10n_extension.dart';

export 'package:submersion/features/insights/presentation/widgets/category_bar_chart.dart';
export 'package:submersion/features/insights/presentation/widgets/distribution_pie_chart.dart';

/// A reusable line chart for trend data
class TrendLineChart extends StatelessWidget {
  final List<TrendDataPoint> data;
  final String? yAxisLabel;
  final Color? lineColor;
  final bool showDots;
  final bool curved;
  final double height;
  final String Function(double)? valueFormatter;
  final String Function(double)? yAxisFormatter;

  const TrendLineChart({
    super.key,
    required this.data,
    this.yAxisLabel,
    this.lineColor,
    this.showDots = true,
    this.curved = true,
    this.height = 200,
    this.valueFormatter,
    this.yAxisFormatter,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.insights_chart_noTrendData,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final color = lineColor ?? Theme.of(context).colorScheme.primary;
    // One axis drives the bounds, the grid lines and the labels, so the lines
    // land under the numbers instead of between them (issue #219).
    final axis = ChartAxis.forTrend(data.map((d) => d.value));

    return Semantics(
      label: yAxisLabel != null
          ? context.l10n.insights_chart_trendSemanticLabelWithAxis(
              data.length,
              yAxisLabel!,
            )
          : context.l10n.insights_chart_trendSemanticLabel(data.length),
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            minY: axis.min,
            maxY: axis.max,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final point = data[spot.spotIndex];
                    final formattedValue =
                        valueFormatter?.call(point.value) ??
                        point.value.toStringAsFixed(1);
                    return LineTooltipItem(
                      '${point.label}\n$formattedValue',
                      TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: _calculateInterval(data.length),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      // Show label based on interval
                      final interval = _calculateInterval(data.length).toInt();
                      if (index % interval == 0 || index == data.length - 1) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data[index].label.split(
                              ' ',
                            )[0], // Just show month abbr
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                axisNameWidget: yAxisLabel != null
                    ? Text(
                        yAxisLabel!,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : null,
                axisNameSize: yAxisLabel != null ? 20 : 0,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  interval: axis.interval,
                  getTitlesWidget: (value, meta) {
                    final formatter = yAxisFormatter ?? valueFormatter;
                    return Text(
                      formatter?.call(value) ?? value.toStringAsFixed(0),
                      style: Theme.of(context).textTheme.bodySmall,
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
            borderData: FlBorderData(
              show: true,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: axis.interval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Theme.of(context).colorScheme.outlineVariant,
                strokeWidth: 1,
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  data.length,
                  (index) => FlSpot(index.toDouble(), data[index].value),
                ),
                isCurved: curved,
                color: color,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: showDots && data.length < 20),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateInterval(int dataLength) {
    if (dataLength <= 6) return 1;
    if (dataLength <= 12) return 2;
    if (dataLength <= 24) return 3;
    if (dataLength <= 36) return 6;
    return (dataLength / 6).ceilToDouble();
  }
}

/// Multi-line chart for comparing multiple trends (e.g., min/avg/max temperature)
class MultiTrendLineChart extends StatelessWidget {
  final List<List<TrendDataPoint>> dataSeries;
  final List<String> seriesLabels;
  final List<Color>? seriesColors;
  final double height;
  final String Function(double)? valueFormatter;

  const MultiTrendLineChart({
    super.key,
    required this.dataSeries,
    required this.seriesLabels,
    this.seriesColors,
    this.height = 200,
    this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    if (dataSeries.isEmpty || dataSeries.every((s) => s.isEmpty)) {
      return SizedBox(
        height: height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.insights_chart_noTrendData,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final defaultColors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
    ];
    final colors = seriesColors ?? defaultColors;

    // Every series shares one axis, and that axis drives the bounds, the grid
    // lines and the labels together, so the numbers sit on the lines instead
    // of on fl_chart's own separate sequence (issues #219, #1354).
    final axis = ChartAxis.forTrend(
      dataSeries.expand((s) => s.map((d) => d.value)),
    );

    final longestSeries = dataSeries.reduce(
      (a, b) => a.length > b.length ? a : b,
    );

    return Semantics(
      label: context.l10n.insights_chart_multiTrendSemanticLabel(
        seriesLabels.join(', '),
      ),
      child: Column(
        children: [
          SizedBox(
            height: height - 30,
            child: LineChart(
              LineChartData(
                minY: axis.min,
                maxY: axis.max,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final point = dataSeries[spot.barIndex][spot.spotIndex];
                        final formattedValue =
                            valueFormatter?.call(point.value) ??
                            point.value.toStringAsFixed(1);
                        final isFirst = identical(spot, touchedSpots.first);
                        return LineTooltipItem(
                          isFirst
                              ? '${point.label}\n$formattedValue'
                              : formattedValue,
                          TextStyle(
                            color: colors[spot.barIndex % colors.length],
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (longestSeries.length / 6).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < longestSeries.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              longestSeries[index].label.split(' ')[0],
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      // Matches the sibling trend chart: a unit-formatted
                      // temperature such as 85.5 F wrapped onto two lines in
                      // the narrower gutter this chart used to reserve.
                      reservedSize: 50,
                      interval: axis.interval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          valueFormatter?.call(value) ??
                              value.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.bodySmall,
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
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: axis.interval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                lineBarsData: List.generate(
                  dataSeries.length,
                  (seriesIndex) => LineChartBarData(
                    spots: List.generate(
                      dataSeries[seriesIndex].length,
                      (index) => FlSpot(
                        index.toDouble(),
                        dataSeries[seriesIndex][index].value,
                      ),
                    ),
                    isCurved: true,
                    color: colors[seriesIndex % colors.length],
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              seriesLabels.length,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 3,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      seriesLabels[index],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
