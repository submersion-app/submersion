import 'package:flutter/material.dart';

import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/formatters/condition_band_label.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_card_parts.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dives per band of a numeric condition, with its coverage line (issue
/// #3118). Renders nothing when no dive has the value.
class ConditionsBandCard extends StatelessWidget {
  const ConditionsBandCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stat,
    required this.totalDives,
    required this.unitSymbol,
    required this.barColor,
  });

  final String title;
  final String subtitle;
  final BandStat stat;
  final int totalDives;

  /// Shown once on the x-axis, so each tick carries just the numbers.
  final String unitSymbol;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    if (stat.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final data = [
      for (final band in stat.bands)
        (
          label: conditionBandLabel(lower: band.lower, upper: band.upper),
          count: band.count,
        ),
    ];
    final description = data
        .map(
          (d) =>
              '${d.label}$unitSymbol: ${l10n.insights_summary_tagUsage_diveCount(d.count)}',
        )
        .join(', ');
    final chart = CategoryBarChart(
      data: data,
      barColor: barColor,
      valueFormatter: l10n.insights_summary_tagUsage_diveCount,
      xAxisLabel: unitSymbol,
    );
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
