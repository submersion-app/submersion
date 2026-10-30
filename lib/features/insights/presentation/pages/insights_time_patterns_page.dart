import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/elapsed_duration_format.dart';

import 'package:submersion/features/insights/domain/time_of_day_bucket.dart';
import 'package:submersion/features/insights/presentation/formatters/distribution_labels.dart';
import 'package:submersion/features/insights/presentation/formatters/time_of_day_colors.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/calendar_day_matrix_card.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class InsightsTimePatternsPage extends ConsumerWidget {
  final bool embedded;

  const InsightsTimePatternsPage({super.key, this.embedded = false});

  List<String> _dayNames(BuildContext context) => [
    context.l10n.insights_timePatterns_dayOfWeek_sun,
    context.l10n.insights_timePatterns_dayOfWeek_mon,
    context.l10n.insights_timePatterns_dayOfWeek_tue,
    context.l10n.insights_timePatterns_dayOfWeek_wed,
    context.l10n.insights_timePatterns_dayOfWeek_thu,
    context.l10n.insights_timePatterns_dayOfWeek_fri,
    context.l10n.insights_timePatterns_dayOfWeek_sat,
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
          const CalendarDayMatrixCard(),
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
        title: Text(context.l10n.insights_timePatterns_appBar_title),
      ),
      body: content,
    );
  }

  Widget _buildDayOfWeekSection(BuildContext context, WidgetRef ref) {
    final dayOfWeekAsync = ref.watch(divesByDayOfWeekProvider);

    return StatSectionCard(
      title: context.l10n.insights_timePatterns_dayOfWeek_title,
      subtitle: context.l10n.insights_timePatterns_dayOfWeek_subtitle,
      child: dayOfWeekAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: Icons.calendar_today,
              message: context.l10n.insights_timePatterns_dayOfWeek_empty,
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
            label: context.l10n.insights_timePatterns_dayOfWeek_semanticLabel(
              description,
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
          message: context.l10n.insights_timePatterns_dayOfWeek_error,
        ),
      ),
    );
  }

  Widget _buildTimeOfDaySection(BuildContext context, WidgetRef ref) {
    final timeOfDayAsync = ref.watch(divesByTimeOfDayProvider);

    return StatSectionCard(
      title: context.l10n.insights_timePatterns_timeOfDay_title,
      subtitle: context.l10n.insights_timePatterns_timeOfDay_subtitle,
      child: timeOfDayAsync.when(
        data: (raw) {
          // The repository's bucket names are stable keys, which the colours
          // are looked up by, so they become display text only here.
          final data = localizeDistribution(
            raw.segments,
            (key) => timeOfDayDistributionLabel(key, context.l10n),
          );
          final description = data
              .map((d) => '${d.label}: ${d.percentage.toStringAsFixed(0)}%')
              .join(', ');
          final brightness = Theme.of(context).brightness;
          final chart = Semantics(
            label: context.l10n.insights_timePatterns_timeOfDay_semanticLabel(
              description,
            ),
            child: DistributionPieChart(
              data: data,
              colors: [
                for (final segment in raw.segments)
                  timeOfDayColor(segment.label, brightness),
              ],
            ),
          );
          if (raw.divesWithoutLocation == 0) return chart;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chart,
              const SizedBox(height: 8),
              Text(
                _defaultSunTimesNote(
                  context,
                  raw.divesWithoutLocation,
                  ref.watch(timeFormatProvider),
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.insights_timePatterns_timeOfDay_error,
        ),
      ),
    );
  }

  /// Tells the diver how many dives were bucketed on the fallback clock
  /// times, with those times in their 12-hour or 24-hour format.
  String _defaultSunTimesNote(
    BuildContext context,
    int dives,
    TimeFormat timeFormat,
  ) {
    String clock(int hour) =>
        DateFormat(timeFormat.pattern).format(DateTime(2000, 1, 1, hour));
    return context.l10n.insights_timePatterns_timeOfDay_defaultSunTimes(
      dives,
      clock(TimeOfDayClassifier.fallbackSunriseHour),
      clock(TimeOfDayClassifier.fallbackSunsetHour),
    );
  }

  Widget _buildSeasonalSection(BuildContext context, WidgetRef ref) {
    final seasonalAsync = ref.watch(divesBySeasonProvider);

    return StatSectionCard(
      title: context.l10n.insights_timePatterns_seasonal_title,
      subtitle: context.l10n.insights_timePatterns_seasonal_subtitle,
      child: seasonalAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: Icons.calendar_month,
              message: context.l10n.insights_timePatterns_seasonal_empty,
            );
          }
          // Fill in missing months with 0
          final monthLabels = insightsMonthLabels(context.l10n);
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
            label: context.l10n.insights_timePatterns_seasonal_semanticLabel(
              description,
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
          message: context.l10n.insights_timePatterns_seasonal_error,
        ),
      ),
    );
  }

  Widget _buildSurfaceIntervalSection(BuildContext context, WidgetRef ref) {
    final siStatsAsync = ref.watch(surfaceIntervalStatsProvider);

    return StatSectionCard(
      title: context.l10n.insights_timePatterns_surfaceInterval_title,
      subtitle: context.l10n.insights_timePatterns_surfaceInterval_subtitle,
      child: siStatsAsync.when(
        data: (data) {
          if (data.avgMinutes == null) {
            return StatEmptyState(
              icon: Icons.timer,
              message: context.l10n.insights_timePatterns_surfaceInterval_empty,
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildSiStat(
                  context,
                  context.l10n.insights_timePatterns_surfaceInterval_average,
                  _formatMinutes(context, data.avgMinutes!),
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSiStat(
                  context,
                  context.l10n.insights_timePatterns_surfaceInterval_minimum,
                  _formatMinutes(context, data.minMinutes ?? 0),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSiStat(
                  context,
                  context.l10n.insights_timePatterns_surfaceInterval_maximum,
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
          message: context.l10n.insights_timePatterns_surfaceInterval_error,
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
      label: context.l10n.insights_timePatterns_surfaceInterval_statLabel(
        label,
        value,
      ),
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

  /// The stats are fractional-minute averages: round once to whole minutes,
  /// then let the shared formatter pick the tier.
  String _formatMinutes(BuildContext context, double minutes) =>
      formatElapsed(context.l10n, Duration(minutes: minutes.round()));
}
