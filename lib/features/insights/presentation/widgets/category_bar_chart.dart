import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:submersion/features/insights/presentation/widgets/chart_axis.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_selection_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A bar chart for categorical data (day of week, months, etc.)
class CategoryBarChart extends StatefulWidget {
  final List<({String label, int count})> data;
  final Color? barColor;
  final double height;
  final String Function(int)? valueFormatter;

  /// Optional unit label rendered once at the top of the y-axis (e.g. "min").
  final String? yAxisLabel;

  /// Optional unit label rendered once below the x-axis (e.g. "m").
  final String? xAxisLabel;

  /// Optional callback to shorten x-axis labels when bars are crowded
  /// (per-bar width below [_compactXThreshold]). Typical use: render a year
  /// like "2024" as "'24" when there isn't room for all four digits.
  final String Function(String)? compactXLabelFormatter;

  /// Per-bar width (in logical pixels) below which [compactXLabelFormatter]
  /// is applied. 50 px comfortably fits 4-digit labels in bodySmall text
  /// with normal inter-bar spacing.
  static const double _compactXThreshold = 50;

  /// Set to let a tap mark a bar and open the dives behind it (issue #3805).
  /// A touch is the only way to read a bar's number on a phone, so the first
  /// tap shows the number and [ChartSelectionStrip] opens it.
  final Future<void> Function(int index)? onOpenBar;

  const CategoryBarChart({
    super.key,
    required this.data,
    this.barColor,
    this.height = 200,
    this.valueFormatter,
    this.yAxisLabel,
    this.xAxisLabel,
    this.compactXLabelFormatter,
    this.onOpenBar,
  });

  @override
  State<CategoryBarChart> createState() => _CategoryBarChartState();
}

class _CategoryBarChartState extends State<CategoryBarChart> {
  /// Width reserved for the left axis labels.
  static const double _leftAxisWidth = 44;

  /// Height of the optional [CategoryBarChart.yAxisLabel], which sits beside
  /// the left axis and so narrows the bars too.
  static const double _leftAxisNameSize = 18;

  /// The chart's border, drawn on every side; [FlBorderData]'s default width.
  static const double _borderWidth = 1;

  int? _marked;

  double get _leftInset =>
      _leftAxisWidth + (widget.yAxisLabel != null ? _leftAxisNameSize : 0);

  @override
  void didUpdateWidget(CategoryBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.data, widget.data)) _marked = null;
  }

  /// Taps go by column rather than by rod, so a very short bar can be hit.
  /// [FlTouchEvent.localPosition] is already measured from the plot area,
  /// which sits inside the left axis and the chart's border.
  void _onTouch(FlTouchEvent event, double chartWidth) {
    if (event is! FlTapUpEvent) return;
    final bars = widget.data.length;
    final plotWidth = chartWidth - _leftInset - _borderWidth * 2;
    final column = event.localPosition.dx / plotWidth * bars;
    final index = column.floor().clamp(0, bars - 1);
    setState(() => _marked = _marked == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final height = widget.height;
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
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.insights_chart_noBarData,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final color = widget.barColor ?? Theme.of(context).colorScheme.primary;
    final onOpenBar = widget.onOpenBar;
    final maxCount = data
        .map((e) => e.count)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    final chart = Semantics(
      label: context.l10n.insights_chart_barSemanticLabel(data.length),
      customSemanticsActions: onOpenBar == null
          ? null
          : {
              for (final (index, item) in data.indexed)
                if (item.count > 0)
                  CustomSemanticsAction(
                    label: context.l10n.insights_chart_linkLabel(
                      context.l10n.insights_chart_viewDives,
                      item.label,
                    ),
                  ): () =>
                      onOpenBar(index),
            },
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Subtract left-axis reserved width from available width before
            // dividing across bars, so the crowding heuristic tracks the
            // actual space each bar receives.
            final chartBodyWidth = (constraints.maxWidth - _leftAxisWidth)
                .clamp(0.0, double.infinity);
            final perBarWidth = data.isEmpty
                ? double.infinity
                : chartBodyWidth / data.length;
            final useCompactXLabels =
                widget.compactXLabelFormatter != null &&
                perBarWidth < CategoryBarChart._compactXThreshold;
            return _buildBarChart(
              context,
              color: color,
              maxCount: maxCount,
              useCompactXLabels: useCompactXLabels,
              chartWidth: constraints.maxWidth,
            );
          },
        ),
      ),
    );
    final marked = _marked;
    if (onOpenBar == null) return chart;
    final item = marked == null ? null : data[marked];
    final xAxisLabel = widget.xAxisLabel;
    // Always a Column: swapping the tree on a mark would rebuild the chart
    // inside its own touch callback.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chart,
        if (item != null)
          ChartSelectionStrip(
            label: xAxisLabel == null
                ? item.label
                : '${item.label} $xAxisLabel',
            countText:
                widget.valueFormatter?.call(item.count) ??
                context.l10n.insights_filterBar_diveCount(item.count),
            onOpen: item.count > 0 ? () => onOpenBar(marked!) : null,
          ),
      ],
    );
  }

  BarChart _buildBarChart(
    BuildContext context, {
    required Color color,
    required double maxCount,
    required bool useCompactXLabels,
    required double chartWidth,
  }) {
    final data = widget.data;
    final valueFormatter = widget.valueFormatter;
    final xAxisLabel = widget.xAxisLabel;
    final yAxisLabel = widget.yAxisLabel;
    final compactXLabelFormatter = widget.compactXLabelFormatter;
    final marked = _marked;
    // Whole-number steps shared by the grid and the labels: the left titles
    // render nothing for a fractional value, so a 2.5 step would otherwise
    // leave unlabelled lines (issue #219).
    final axis = ChartAxis.forCounts(maxCount);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: axis.min,
        maxY: axis.max,
        barTouchData: BarTouchData(
          touchCallback: widget.onOpenBar == null
              ? null
              : (event, _) => _onTouch(event, chartWidth),
          mouseCursorResolver: widget.onOpenBar == null
              ? null
              : (_, _) => SystemMouseCursors.click,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = data[groupIndex];
              final formattedValue =
                  valueFormatter?.call(item.count) ?? '${item.count}';
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
            axisNameWidget: xAxisLabel != null
                ? Text(xAxisLabel, style: Theme.of(context).textTheme.bodySmall)
                : null,
            axisNameSize: xAxisLabel != null ? 18 : 0,
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const Text('');
                }
                final rawLabel = data[index].label;
                final label = useCompactXLabels
                    ? compactXLabelFormatter!(rawLabel)
                    : rawLabel;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: yAxisLabel != null
                ? Text(yAxisLabel, style: Theme.of(context).textTheme.bodySmall)
                : null,
            axisNameSize: yAxisLabel != null ? 18 : 0,
            sideTitles: SideTitles(
              showTitles: true,
              // Room for up to 4-digit right-aligned integers.
              reservedSize: _leftAxisWidth,
              interval: axis.interval,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) {
                  return const Text('');
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value.toInt().toString(),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
        barGroups: List.generate(
          data.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data[index].count.toDouble(),
                color: marked == null || marked == index
                    ? color
                    : color.withValues(alpha: 0.35),
                width: data.length > 12 ? 12 : 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
