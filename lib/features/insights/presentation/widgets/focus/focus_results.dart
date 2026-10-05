import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_group.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_dive_list.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_factors_table.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Everything under the selector: summary, chart, dive list and factors.
class FocusResults extends ConsumerWidget {
  const FocusResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selection = ref.watch(focusSelectionProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final metricUnits = FocusMetricUnits(selection.metric, units);

    // A new selection is a reload: keep the previous group on screen until
    // the new one lands, so the results do not flash a spinner and the chart
    // keeps its State (and any zoom the diver set).
    return ref
        .watch(focusGroupProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => StatEmptyState(
            icon: Icons.error_outline,
            message: l10n.insights_focus_error,
          ),
          data: (group) {
            if (group.population.isEmpty) {
              return StatEmptyState(
                icon: Icons.filter_center_focus,
                message: l10n.insights_focus_empty,
              );
            }
            final message = _message(context, selection, group, metricUnits);
            if (group.members.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(message),
              );
            }
            final rows = <String, FocusFactorRow>{
              for (final r
                  in ref.watch(focusFactorRowsProvider).value ??
                      const <FocusFactorRow>[])
                r.diveId: r,
            };
            final theme = Theme.of(context);
            final memberIds = group.memberIds;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                StatSectionCard(
                  title: l10n.insights_focus_chart_title,
                  child: DiveTrendChart(
                    chartId: 'focus',
                    points: [
                      for (final p in group.population)
                        if (!memberIds.contains(p.diveId)) p,
                    ],
                    secondarySeries: [
                      TrendSeries(
                        label: l10n.insights_focus_chart_group,
                        points: group.members,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                    // Muted enough that the group, in the accent, reads at a
                    // glance among a long logbook's other dives.
                    pointColor: theme.colorScheme.outlineVariant,
                    dateFormat: ref.watch(dateFormatProvider),
                    valueFormatter: (v) => metricUnits.format(v, l10n),
                    yAxisFormatter: (v) =>
                        metricUnits.toDisplay(v).toStringAsFixed(1),
                    onDiveSelected: (id) => context.push('/dives/$id'),
                  ),
                ),
                const SizedBox(height: 16),
                StatSectionCard(
                  title: l10n.insights_focus_list_title,
                  child: FocusDiveList(
                    members: group.members,
                    rows: rows,
                    metricUnits: metricUnits,
                    ranked: selection.mode.isRanked,
                  ),
                ),
                const SizedBox(height: 16),
                StatSectionCard(
                  title: l10n.insights_focus_factors_title,
                  subtitle: l10n.insights_focus_factors_subtitle,
                  child: ref
                      .watch(focusFactorReportProvider)
                      .when(
                        skipLoadingOnReload: true,
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => Text(l10n.insights_focus_error),
                        data: (report) => FocusFactorsTable(report: report),
                      ),
                ),
              ],
            );
          },
        );
  }

  String _message(
    BuildContext context,
    FocusSelection selection,
    FocusGroup group,
    FocusMetricUnits metricUnits,
  ) {
    final l10n = context.l10n;
    final threshold = selection.threshold;
    if (!selection.mode.isRanked && threshold == null) {
      return l10n.insights_focus_enterValue;
    }
    if (group.members.isEmpty) {
      final value = metricUnits.format(threshold!, l10n);
      final min = metricUnits.format(group.populationMin!, l10n);
      final max = metricUnits.format(group.populationMax!, l10n);
      return selection.mode == FocusMode.above
          ? l10n.insights_focus_noMatch_above(value, min, max)
          : l10n.insights_focus_noMatch_below(value, min, max);
    }
    if (selection.mode.isRanked && selection.count > group.population.length) {
      return l10n.insights_focus_summary_allShown(group.population.length);
    }
    return l10n.insights_focus_summary(
      group.members.length,
      group.population.length,
      metricUnits.format(group.memberMean!, l10n),
      metricUnits.format(group.populationMean!, l10n),
    );
  }
}
