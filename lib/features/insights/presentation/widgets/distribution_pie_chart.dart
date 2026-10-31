import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_row_link.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_selection_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A reusable pie chart for distribution data
class DistributionPieChart extends StatefulWidget {
  final List<DistributionSegment> data;
  final List<Color>? colors;
  final double height;
  final bool showLegend;
  final bool showPercentage;

  /// Set to open the dives behind a segment (issue #3805). A slice marks
  /// first, showing its count, and [ChartSelectionStrip] opens it; a legend
  /// row opens in one tap.
  final Future<void> Function(int index)? onOpenSegment;

  const DistributionPieChart({
    super.key,
    required this.data,
    this.colors,
    this.height = 200,
    this.showLegend = true,
    this.showPercentage = true,
    this.onOpenSegment,
  });

  @override
  State<DistributionPieChart> createState() => _DistributionPieChartState();
}

class _DistributionPieChartState extends State<DistributionPieChart> {
  int? _marked;

  @override
  void didUpdateWidget(DistributionPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSegments(oldWidget.data, widget.data)) _marked = null;
  }

  // DistributionSegment has no value equality.
  bool _sameSegments(
    List<DistributionSegment> a,
    List<DistributionSegment> b,
  ) => listEquals(_keys(a), _keys(b));

  List<(String, int)> _keys(List<DistributionSegment> segments) => [
    for (final s in segments) (s.label, s.count),
  ];

  void _onTouch(FlTouchEvent event, PieTouchResponse? response) {
    if (event is! FlTapUpEvent) return;
    final index = response?.touchedSection?.touchedSectionIndex;
    if (index == null || index < 0) return;
    setState(() => _marked = _marked == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final height = widget.height;
    final colors = widget.colors;
    final showLegend = widget.showLegend;
    final showPercentage = widget.showPercentage;
    final onOpenSegment = widget.onOpenSegment;
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

    final marked = _marked;
    final chart = Semantics(
      label: context.l10n.insights_chart_distributionSemanticLabel(data.length),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              // A legend with chevrons takes a little from the pie, so its
              // labels keep their room.
              flex: !showLegend
                  ? 1
                  : onOpenSegment == null
                  ? 2
                  : 3,
              child: PieChart(
                PieChartData(
                  pieTouchData: onOpenSegment == null
                      ? null
                      : PieTouchData(
                          touchCallback: _onTouch,
                          mouseCursorResolver: (_, _) =>
                              SystemMouseCursors.click,
                        ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: List.generate(data.length, (index) {
                    final segment = data[index];
                    final color = chartColors[index % chartColors.length];
                    final isDimmed = marked != null && marked != index;
                    return PieChartSectionData(
                      value: segment.count.toDouble(),
                      title: showPercentage
                          ? '${segment.percentage.toStringAsFixed(0)}%'
                          : '${segment.count}',
                      color: isDimmed ? color.withValues(alpha: 0.35) : color,
                      radius: marked == index ? 64 : 60,
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
                flex: onOpenSegment == null ? 1 : 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(data.length, (index) {
                    final segment = data[index];
                    final color = chartColors[index % chartColors.length];
                    final row = Padding(
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
                          if (onOpenSegment != null && segment.count > 0)
                            const Icon(Icons.chevron_right, size: 16),
                        ],
                      ),
                    );
                    if (onOpenSegment == null || segment.count == 0) {
                      return row;
                    }
                    return ChartRowLink(
                      onTap: () => onOpenSegment(index),
                      child: row,
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onOpenSegment == null) return chart;
    final segment = marked == null ? null : data[marked];
    // Always a Column: swapping the tree on a mark would rebuild the chart
    // inside its own touch callback.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chart,
        if (segment != null)
          ChartSelectionStrip(
            label: segment.label,
            countText: context.l10n.insights_filterBar_diveCount(segment.count),
            onOpen: segment.count > 0 ? () => onOpenSegment(marked!) : null,
          ),
      ],
    );
  }
}
