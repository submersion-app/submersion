import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_group.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_labels.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_dive_list.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_factors_table.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_standouts_card.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_reference_line.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Everything under the sentence: summary, what stands out, chart, full
/// comparison and the dives, in that order, so the finding leads and the
/// list is evidence.
///
/// Builds a sliver so the dive list can be lazy (#3013); the page places it
/// in a [CustomScrollView].
class FocusResults extends ConsumerStatefulWidget {
  const FocusResults({super.key});

  /// Rows the dive list shows before "Show all".
  static const int previewRows = 5;

  @override
  ConsumerState<FocusResults> createState() => _FocusResultsState();
}

class _FocusResultsState extends ConsumerState<FocusResults> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A new selection is a new group, so the list folds again.
    ref.listen(focusSelectionProvider, (_, _) {
      if (_showAll) setState(() => _showAll = false);
    });
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
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, _) => SliverToBoxAdapter(
            child: StatEmptyState(
              icon: Icons.error_outline,
              message: l10n.insights_focus_error,
            ),
          ),
          data: (group) {
            if (group.population.isEmpty) {
              return SliverToBoxAdapter(
                child: StatEmptyState(
                  icon: Icons.filter_center_focus,
                  message: l10n.insights_focus_empty,
                ),
              );
            }
            final message = _message(context, selection, group, metricUnits);
            if (group.members.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(message),
                ),
              );
            }
            final rows = ref.watch(focusFactorRowsByIdProvider);
            final theme = Theme.of(context);
            final report = ref.watch(focusFactorReportProvider);
            final members = _showAll
                ? group.members
                : group.members
                      .take(FocusResults.previewRows)
                      .toList(growable: false);
            final hidden = group.members.length - members.length;
            final threshold = selection.threshold;
            // Built once: the getter makes a fresh Set on every call.
            final memberIds = group.memberIds;
            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      report.when(
                        skipLoadingOnReload: true,
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => StatSectionCard(
                          title: l10n.insights_focus_standouts_title,
                          child: Text(l10n.insights_focus_error),
                        ),
                        data: (r) => FocusStandoutsCard(report: r),
                      ),
                      const SizedBox(height: 16),
                      StatSectionCard(
                        title: l10n.insights_focus_chart_title(
                          focusMetricLabel(selection.metric, l10n),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Legend(
                              key: const ValueKey('focus-legend'),
                              group: theme.colorScheme.primary,
                              others: theme.colorScheme.outlineVariant,
                            ),
                            const SizedBox(height: 8),
                            DiveTrendChart(
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
                                  // Twice the primary's dot, so the group
                                  // reads at a glance among a long logbook.
                                  pointRadius: 4.4,
                                ),
                              ],
                              pointColor: theme.colorScheme.outlineVariant,
                              referenceLine:
                                  selection.mode.isRanked || threshold == null
                                  ? null
                                  : TrendReferenceLine(
                                      value: threshold,
                                      label: metricUnits.format(
                                        threshold,
                                        l10n,
                                      ),
                                    ),
                              dateFormat: ref.watch(dateFormatProvider),
                              gapThreshold: ref.watch(
                                trendGapThresholdProvider,
                              ),
                              valueFormatter: (v) =>
                                  metricUnits.format(v, l10n),
                              yAxisFormatter: (v) =>
                                  metricUnits.toDisplay(v).toStringAsFixed(1),
                              onDiveSelected: (id) =>
                                  context.push('/dives/$id'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      report.when(
                        skipLoadingOnReload: true,
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => StatSectionCard(
                          title: l10n.insights_focus_comparison_title,
                          child: Text(l10n.insights_focus_error),
                        ),
                        data: (r) => FocusFactorsTable(
                          report: r,
                          metric: selection.metric,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                SliverStatSectionCard(
                  title: l10n.insights_focus_list_title,
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      FocusDiveList(
                        members: members,
                        rows: rows,
                        metricUnits: metricUnits,
                        ranked: selection.mode.isRanked,
                      ),
                      if (hidden > 0)
                        SliverToBoxAdapter(
                          child: Center(
                            child: TextButton(
                              key: const ValueKey('focus-list-show-all'),
                              onPressed: () => setState(() => _showAll = true),
                              child: Text(
                                l10n.insights_focus_list_showAll(
                                  group.members.length,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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

/// Which dots are the group: a swatch and a label for each series.
class _Legend extends StatelessWidget {
  const _Legend({super.key, required this.group, required this.others});

  final Color group;
  final Color others;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.labelMedium;
    Widget entry(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        entry(group, l10n.insights_focus_chart_group),
        entry(others, l10n.insights_focus_chart_others),
      ],
    );
  }
}
