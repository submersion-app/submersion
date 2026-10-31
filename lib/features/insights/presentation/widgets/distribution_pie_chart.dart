import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.insights_chart_noDistributionData,
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

    return Semantics(
      label: context.l10n.insights_chart_distributionSemanticLabel(data.length),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              flex: showLegend ? 2 : 1,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: List.generate(data.length, (index) {
                    final segment = data[index];
                    final color = chartColors[index % chartColors.length];
                    return PieChartSectionData(
                      value: segment.count.toDouble(),
                      title: showPercentage
                          ? '${segment.percentage.toStringAsFixed(0)}%'
                          : '${segment.count}',
                      color: color,
                      radius: 60,
                      // White on a dark slice, near-black on a light one:
                      // white alone is unreadable on a pale colour.
                      titleStyle: TextStyle(
                        color:
                            ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }),
                ),
              ),
            ),
            if (showLegend) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(data.length, (index) {
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
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
