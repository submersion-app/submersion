import 'package:flutter/material.dart';

import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_card_parts.dart';
import 'package:submersion/features/insights/presentation/widgets/horizontal_category_bar_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How a categorical condition is drawn: a pie for a short ordinal scale
/// (cloud cover, current strength), horizontal bars for longer lists whose
/// labels need room (precipitation, compass directions, methods).
enum ConditionsChartKind { pie, bar }

/// Dives per value of a categorical condition, with its coverage line (issue
/// #3118). Renders nothing when no dive has the value.
class ConditionsCategoryCard<T extends Enum> extends StatelessWidget {
  const ConditionsCategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stat,
    required this.totalDives,
    required this.labelOf,
    required this.kind,
    this.colorOf,
    this.barColor,
  });

  final String title;
  final String subtitle;
  final CategoryStat<T> stat;
  final int totalDives;
  final String Function(T) labelOf;
  final ConditionsChartKind kind;

  /// Pie slice color per value, so a value keeps its color whatever its
  /// share. Null uses the chart's default palette.
  final Color Function(T)? colorOf;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    if (stat.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final description = stat.counts
        .map(
          (c) =>
              '${labelOf(c.value)}: ${l10n.insights_summary_tagUsage_diveCount(c.count)}',
        )
        .join(', ');
    final colorOf = this.colorOf;
    final chart = switch (kind) {
      ConditionsChartKind.pie => DistributionPieChart(
        data: [
          for (final c in stat.counts)
            DistributionSegment(
              label: labelOf(c.value),
              count: c.count,
              percentage: c.count / stat.recorded * 100,
            ),
        ],
        colors: colorOf == null
            ? null
            : [for (final c in stat.counts) colorOf(c.value)],
      ),
      ConditionsChartKind.bar => HorizontalCategoryBarChart(
        data: [
          for (final c in stat.counts)
            (label: labelOf(c.value), count: c.count),
        ],
        barColor: barColor,
      ),
    };
    return ConditionsChartCard(
      title: title,
      subtitle: subtitle,
      description: description,
      chart: chart,
      recorded: stat.recorded,
      total: totalDives,
    );
  }
}
