import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A horizontal marker on a trend chart: a threshold the diver set, drawn
/// dashed with its formatted value beside it.
@immutable
class TrendReferenceLine {
  const TrendReferenceLine({required this.value, required this.label});

  /// In the chart's y units (storage units).
  final double value;
  final String label;
}

/// fl_chart's extra lines for [line]; none when it is null. Kept out of
/// `dive_trend_chart.dart`, which sits at the file-size limit.
ExtraLinesData trendReferenceLines(
  BuildContext context,
  TrendReferenceLine? line,
) {
  if (line == null) return const ExtraLinesData();
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return ExtraLinesData(
    horizontalLines: [
      HorizontalLine(
        y: line.value,
        color: scheme.tertiary,
        strokeWidth: 1.5,
        dashArray: const [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 4, bottom: 2),
          style: theme.textTheme.labelSmall?.copyWith(color: scheme.tertiary),
          labelResolver: (_) => line.label,
        ),
      ),
    ],
  );
}
