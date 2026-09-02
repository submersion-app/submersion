import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_bar.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_action.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsProgressionPage extends ConsumerWidget {
  final bool embedded;

  const StatisticsProgressionPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDepthProgressionSection(context, ref, units),
          const SizedBox(height: 16),
          _buildBottomTimeSection(context, ref),
          const SizedBox(height: 16),
          _buildDivesPerYearSection(context, ref),
          const SizedBox(height: 16),
          _buildDivesBySuitThicknessSection(context, ref),
          const SizedBox(height: 16),
          _buildCumulativeSection(context, ref),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statistics_progression_appBar_title),
        actions: const [StatisticsFilterAction()],
      ),
      // Expanded is required: content is a SingleChildScrollView, and a
      // Column would otherwise hand it unbounded height.
      body: Column(
        children: [
          const StatisticsFilterBar(),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildDepthProgressionSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    return TrendChartSection(
      chartId: TrendChartIds.depth,
      onDiveSelected: (diveId) => context.push('/dives/$diveId'),
      title: context.l10n.statistics_progression_depthProgression_title,
      subtitle: context.l10n.statistics_progression_depthProgression_subtitle,
      pointsAsync: ref.watch(depthProgressionTrendProvider),
      errorMessage: context.l10n.statistics_progression_depthProgression_error,
      lineColor: Colors.indigo,
      valueFormatter: (value) => units.formatDepth(value),
      rateFormatter: (value) => units.formatDepth(value),
    );
  }

  Widget _buildBottomTimeSection(BuildContext context, WidgetRef ref) {
    String minutes(double value) =>
        context.l10n.surfaceInterval_format_minutes(value.toStringAsFixed(0));

    return TrendChartSection(
      chartId: TrendChartIds.bottomTime,
      onDiveSelected: (diveId) => context.push('/dives/$diveId'),
      title: context.l10n.statistics_progression_bottomTime_title,
      subtitle: context.l10n.statistics_progression_bottomTime_subtitle,
      pointsAsync: ref.watch(bottomTimeTrendProvider),
      errorMessage: context.l10n.statistics_progression_bottomTime_error,
      lineColor: Colors.teal,
      valueFormatter: minutes,
      rateFormatter: minutes,
    );
  }

  Widget _buildDivesPerYearSection(BuildContext context, WidgetRef ref) {
    final divesPerYearAsync = ref.watch(divesPerYearProvider);

    return StatSectionCard(
      title: context.l10n.statistics_progression_divesPerYear_title,
      subtitle: context.l10n.statistics_progression_divesPerYear_subtitle,
      child: divesPerYearAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: Icons.bar_chart,
              message: context.l10n.statistics_progression_divesPerYear_empty,
            );
          }
          final chartData = data
              .map((d) => (label: '${d.year}', count: d.count))
              .toList();
          final description = data
              .map(
                (d) => context.l10n
                    .statistics_progression_divesPerYear_countInYear(
                      d.count,
                      '${d.year}',
                    ),
              )
              .join(', ');
          return Semantics(
            label: context.l10n
                .statistics_progression_divesPerYear_semanticLabel(description),
            child: CategoryBarChart(
              data: chartData,
              barColor: Theme.of(context).colorScheme.primary,
              // When bars are crowded, compact "2024" → "'24" so 4-digit
              // years don't overrun each other on narrow screens.
              compactXLabelFormatter: (year) =>
                  year.length == 4 ? "'${year.substring(2)}" : year,
            ),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_progression_divesPerYear_error,
        ),
      ),
    );
  }

  Widget _buildDivesBySuitThicknessSection(
    BuildContext context,
    WidgetRef ref,
  ) {
    final thicknessAsync = ref.watch(divesBySuitThicknessProvider);

    // Space before the unit ("5 mm"), matching the attribute formatter and
    // the rest of the app's thickness rendering.
    String label(double mm) =>
        mm == mm.roundToDouble() ? '${mm.toStringAsFixed(0)} mm' : '$mm mm';

    return StatSectionCard(
      title: context.l10n.statistics_progression_divesBySuitThickness_title,
      subtitle:
          context.l10n.statistics_progression_divesBySuitThickness_subtitle,
      child: thicknessAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: Icons.bar_chart,
              message: context
                  .l10n
                  .statistics_progression_divesBySuitThickness_empty,
            );
          }
          final chartData = data
              .map((d) => (label: label(d.mm), count: d.count))
              .toList();
          // Locale-neutral label:count pairs so the screen-reader summary
          // matches the app locale rather than hard-coded English prose.
          final description = data
              .map((d) => '${label(d.mm)}: ${d.count}')
              .join(', ');
          return Semantics(
            label: context.l10n
                .statistics_progression_divesBySuitThickness_semanticLabel(
                  description,
                ),
            child: CategoryBarChart(
              data: chartData,
              barColor: Theme.of(context).colorScheme.tertiary,
            ),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message:
              context.l10n.statistics_progression_divesBySuitThickness_error,
        ),
      ),
    );
  }

  Widget _buildCumulativeSection(BuildContext context, WidgetRef ref) {
    final cumulativeAsync = ref.watch(cumulativeDiveCountProvider);

    return StatSectionCard(
      title: context.l10n.statistics_progression_cumulative_title,
      subtitle: context.l10n.statistics_progression_cumulative_subtitle,
      child: cumulativeAsync.when(
        // A date axis, not the index axis: the count now steps once per dive,
        // so a trip is a run of steps rather than one. No aggregation or fit
        // controls, because a mean of a running total says nothing.
        data: (data) => DiveTrendChart(
          points: data,
          pointColor: Colors.green,
          valueFormatter: (value) => value.toStringAsFixed(0),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_progression_cumulative_error,
        ),
      ),
    );
  }
}
