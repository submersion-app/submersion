import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/utils/hours_minutes.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The whole of a repetitive series, above the selected dive's results (issue
/// #3565): total time, highest CNS, daily OTU, and when the diver can fly.
/// Nothing on a single dive.
class PlanSeriesSummaryCard extends ConsumerWidget {
  const PlanSeriesSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(planSeriesSummaryProvider);
    if (summary == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final until = summary.noFlyUntil;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );

    return Card(
      key: const Key('planSeriesSummary'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.plannerSeries_summary_title,
              style: theme.textTheme.titleSmall,
            ),
            row(
              l10n.plannerSeries_summary_total,
              formatHoursMinutes(Duration(seconds: summary.totalSeconds)),
            ),
            row(
              l10n.plannerSeries_summary_highestCns,
              '${summary.highestCns.round()}%',
            ),
            row(
              l10n.plannerSeries_summary_dailyOtu,
              '${summary.dailyOtu.round()}',
            ),
            row(
              l10n.plannerSeries_summary_noFly,
              until == null
                  ? l10n.plannerSeries_summary_noFlyWait(
                      formatHoursMinutes(summary.noFlyWait),
                    )
                  : units.formatDateTimeBullet(until),
            ),
          ],
        ),
      ),
    );
  }
}
