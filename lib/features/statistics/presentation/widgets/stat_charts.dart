import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/statistics_repository.dart';

/// A reusable line chart for trend data
class TrendLineChart extends StatelessWidget {
  final List<TrendDataPoint> data;
  final String? yAxisLabel;
  final Color? lineColor;
  final bool showDots;
  final bool curved;
  final double height;
  final String Function(double)? valueFormatter;

  const TrendLineChart({
    super.key,
    required this.data,
    this.yAxisLabel,
    this.lineColor,
    this.showDots = true,
    this.curved = true,
    this.height = 200,
    this.valueFormatter,
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No trend data available',
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
    final values = data.map((d) => d.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY > 0 ? (minY - padding).clamp(0, double.infinity) : minY - padding,
          maxY: maxY + padding,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final point = data[spot.spotIndex];
                  final formattedValue = valueFormatter?.call(point.value) ?? point.value.toStringAsFixed(1);
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
                          data[index].label.split(' ')[0], // Just show month abbr
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
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    valueFormatter?.call(value) ?? value.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
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

/// A reusable pie chart for distribution data
class DistributionPieChart extends StatelessWidget {
  final List<DistributionSegment> data;
  final List<Color>? colors;
  final double height;
  final bool showLegend;
  final bool showPercentage;

  const DistributionPieChart({
    super.key,
    required this.data,
    this.colors,
    this.height = 200,
    this.showLegend = true,
    this.showPercentage = true,
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
                Icons.pie_chart_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No distribution data available',
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
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.indigo,
    ];

    final chartColors = colors ?? defaultColors;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            flex: showLegend ? 2 : 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: List.generate(
                  data.length,
                  (index) {
                    final segment = data[index];
                    final color = chartColors[index % chartColors.length];
                    return PieChartSectionData(
                      value: segment.count.toDouble(),
                      title: showPercentage ? '${segment.percentage.toStringAsFixed(0)}%' : '${segment.count}',
                      color: color,
                      radius: 60,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (showLegend) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  data.length,
                  (index) {
                    final segment = data[index];
                    final color = chartColors[index % chartColors.length];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              segment.label,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A bar chart for categorical data (day of week, months, etc.)
class CategoryBarChart extends StatelessWidget {
  final List<({String label, int count})> data;
  final Color? barColor;
  final double height;
  final String Function(int)? valueFormatter;

  const CategoryBarChart({
    super.key,
    required this.data,
    this.barColor,
    this.height = 200,
    this.valueFormatter,
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
                Icons.bar_chart,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final color = barColor ?? Theme.of(context).colorScheme.primary;
    final maxCount = data.map((e) => e.count).reduce((a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount + (maxCount * 0.1),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = data[groupIndex];
                final formattedValue = valueFormatter?.call(item.count) ?? '${item.count}';
                return BarTooltipItem(
                  '${item.label}\n$formattedValue',
                  TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        data[index].label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == value.roundToDouble()) {
                    return Text(
                      value.toInt().toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxCount > 0 ? maxCount / 4 : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 1,
            ),
          ),
          barGroups: List.generate(
            data.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data[index].count.toDouble(),
                  color: color,
                  width: data.length > 12 ? 12 : 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No trend data available',
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

    final allValues = dataSeries.expand((s) => s.map((d) => d.value)).toList();
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    final longestSeries = dataSeries.reduce((a, b) => a.length > b.length ? a : b);

    return Column(
      children: [
        SizedBox(
          height: height - 30,
          child: LineChart(
            LineChartData(
              minY: minY - padding,
              maxY: maxY + padding,
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
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        valueFormatter?.call(value) ?? value.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
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
                    (index) => FlSpot(index.toDouble(), dataSeries[seriesIndex][index].value),
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
    );
  }
}
