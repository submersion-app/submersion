import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsTimePatternsPage extends ConsumerWidget {
  final bool embedded;

  const StatisticsTimePatternsPage({super.key, this.embedded = false});

  List<String> _dayNames(BuildContext context) => [
    context.l10n.statistics_timePatterns_dayOfWeek_sun,
    context.l10n.statistics_timePatterns_dayOfWeek_mon,
    context.l10n.statistics_timePatterns_dayOfWeek_tue,
    context.l10n.statistics_timePatterns_dayOfWeek_wed,
    context.l10n.statistics_timePatterns_dayOfWeek_thu,
    context.l10n.statistics_timePatterns_dayOfWeek_fri,
    context.l10n.statistics_timePatterns_dayOfWeek_sat,
  ];
  List<String> _monthNames(BuildContext context) => [
    context.l10n.statistics_timePatterns_month_jan,
    context.l10n.statistics_timePatterns_month_feb,
    context.l10n.statistics_timePatterns_month_mar,
    context.l10n.statistics_timePatterns_month_apr,
    context.l10n.statistics_timePatterns_month_may,
    context.l10n.statistics_timePatterns_month_jun,
    context.l10n.statistics_timePatterns_month_jul,
    context.l10n.statistics_timePatterns_month_aug,
    context.l10n.statistics_timePatterns_month_sep,
    context.l10n.statistics_timePatterns_month_oct,
    context.l10n.statistics_timePatterns_month_nov,
    context.l10n.statistics_timePatterns_month_dec,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDayOfWeekSection(context, ref),
          const SizedBox(height: 16),
          _buildTimeOfDaySection(context, ref),
          const SizedBox(height: 16),
          _buildSeasonalSection(context, ref),
          const SizedBox(height: 16),
          _buildSurfaceIntervalSection(context, ref),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statistics_timePatterns_appBar_title),
      ),
      body: content,
    );
  }

  Widget _buildDayOfWeekSection(BuildContext context, WidgetRef ref) {
    final dayOfWeekAsync = ref.watch(divesByDayOfWeekProvider);

    return StatSectionCard(
      title: context.l10n.statistics_timePatterns_dayOfWeek_title,
      subtitle: context.l10n.statistics_timePatterns_dayOfWeek_subtitle,
      child: dayOfWeekAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: Icons.calendar_today,
              message: context.l10n.statistics_timePatterns_dayOfWeek_empty,
            );
          }
          // Fill in missing days with 0
          final dayLabels = _dayNames(context);
          final fullData = List.generate(7, (day) {
            final existing = data.firstWhere(
              (d) => d.dayOfWeek == day,
              orElse: () => (dayOfWeek: day, count: 0),
            );
            return (label: dayLabels[day], count: existing.count);
          });
          final description = fullData
              .where((d) => d.count > 0)
              .map((d) => '${d.label}: ${d.count}')
              .join(', ');
          return Semantics(
            label: chartSummaryLabel(
              chartType: 'Bar',
              description: 'Dives by day of week. $description',
            ),
            child: CategoryBarChart(data: fullData, barColor: Colors.blue),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_timePatterns_dayOfWeek_error,
        ),
      ),
    );
  }

  Widget _buildTimeOfDaySection(BuildContext context, WidgetRef ref) {
    final timeOfDayAsync = ref.watch(divesByTimeOfDayProvider);

    return StatSectionCard(
      title: context.l10n.statistics_timePatterns_timeOfDay_title,
      subtitle: context.l10n.statistics_timePatterns_timeOfDay_subtitle,
      child: timeOfDayAsync.when(
        data: (data) {
          final description = data
              .map((d) => '${d.label}: ${d.percentage.toStringAsFixed(0)}%')
              .join(', ');
          return Semantics(
            label: chartSummaryLabel(
              chartType: 'Pie',
              description: 'Dives by time of day. $description',
            ),
            child: DistributionPieChart(
              data: data,
              colors: const [
                Colors.amber, // Morning
                Colors.orange, // Afternoon
                Colors.deepOrange, // Evening
                Colors.indigo, // Night
              ],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_timePatterns_timeOfDay_error,
        ),
      ),
    );
  }

  Widget _buildSeasonalSection(BuildContext context, WidgetRef ref) {
    final seasonalAsync = ref.watch(divesBySeasonProvider);

    return StatSectionCard(
      title: context.l10n.statistics_timePatterns_seasonal_title,
      subtitle: context.l10n.statistics_timePatterns_seasonal_subtitle,
      child: seasonalAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: Icons.calendar_month,
              message: context.l10n.statistics_timePatterns_seasonal_empty,
            );
          }
          // Fill in missing months with 0
          final monthLabels = _monthNames(context);
          final fullData = List.generate(12, (month) {
            final m = month + 1;
            final existing = data.firstWhere(
              (d) => d.month == m,
              orElse: () => (month: m, count: 0),
            );
            return (label: monthLabels[month], count: existing.count);
          });
          final description = fullData
              .where((d) => d.count > 0)
              .map((d) => '${d.label}: ${d.count}')
              .join(', ');
          return Semantics(
            label: chartSummaryLabel(
              chartType: 'Bar',
              description: 'Dives by month. $description',
            ),
            child: CategoryBarChart(data: fullData, barColor: Colors.teal),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_timePatterns_seasonal_error,
        ),
      ),
    );
  }

  Widget _buildSurfaceIntervalSection(BuildContext context, WidgetRef ref) {
    final siStatsAsync = ref.watch(surfaceIntervalStatsProvider);

    return StatSectionCard(
      title: context.l10n.statistics_timePatterns_surfaceInterval_title,
      subtitle: context.l10n.statistics_timePatterns_surfaceInterval_subtitle,
      child: siStatsAsync.when(
        data: (data) {
          if (data.avgMinutes == null) {
            return StatEmptyState(
              icon: Icons.timer,
              message:
                  context.l10n.statistics_timePatterns_surfaceInterval_empty,
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildSiStat(
                  context,
                  context.l10n.statistics_timePatterns_surfaceInterval_average,
                  _formatMinutes(context, data.avgMinutes!),
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSiStat(
                  context,
                  context.l10n.statistics_timePatterns_surfaceInterval_minimum,
                  _formatMinutes(context, data.minMinutes ?? 0),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSiStat(
                  context,
                  context.l10n.statistics_timePatterns_surfaceInterval_maximum,
                  _formatMinutes(context, data.maxMinutes ?? 0),
                  Colors.orange,
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_timePatterns_surfaceInterval_error,
        ),
      ),
    );
  }

  Widget _buildSiStat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Semantics(
      label: statLabel(name: '$label surface interval', value: value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(BuildContext context, double minutes) {
    if (minutes < 60) {
      return context.l10n.statistics_timePatterns_surfaceInterval_formatMinutes(
        minutes.round(),
      );
    }
    final hours = (minutes / 60).floor();
    final mins = (minutes % 60).round();
    return context.l10n
        .statistics_timePatterns_surfaceInterval_formatHoursMinutes(
          hours,
          mins,
        );
  }
}
