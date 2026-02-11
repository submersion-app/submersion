import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsConditionsPage extends ConsumerWidget {
  final bool embedded;

  const StatisticsConditionsPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVisibilitySection(context, ref),
          const SizedBox(height: 16),
          _buildWaterTypeSection(context, ref),
          const SizedBox(height: 16),
          _buildEntryMethodSection(context, ref),
          const SizedBox(height: 16),
          _buildTemperatureSection(context, ref, units),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statistics_conditions_appBar_title),
      ),
      body: content,
    );
  }

  Widget _buildVisibilitySection(BuildContext context, WidgetRef ref) {
    final visibilityAsync = ref.watch(visibilityDistributionProvider);

    return StatSectionCard(
      title: context.l10n.statistics_conditions_visibility_title,
      subtitle: context.l10n.statistics_conditions_visibility_subtitle,
      child: visibilityAsync.when(
        data: (data) {
          final description = data
              .map((d) => '${d.label}: ${d.percentage.toStringAsFixed(0)}%')
              .join(', ');
          return Semantics(
            label: chartSummaryLabel(
              chartType: 'Pie',
              description: 'Visibility distribution. $description',
            ),
            child: DistributionPieChart(
              data: data,
              colors: [
                Colors.green.shade400,
                Colors.blue.shade400,
                Colors.orange.shade400,
                Colors.grey.shade400,
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
          message: context.l10n.statistics_conditions_visibility_error,
        ),
      ),
    );
  }

  Widget _buildWaterTypeSection(BuildContext context, WidgetRef ref) {
    final waterTypeAsync = ref.watch(waterTypeDistributionProvider);

    return StatSectionCard(
      title: context.l10n.statistics_conditions_waterType_title,
      subtitle: context.l10n.statistics_conditions_waterType_subtitle,
      child: waterTypeAsync.when(
        data: (data) {
          final description = data
              .map((d) => '${d.label}: ${d.percentage.toStringAsFixed(0)}%')
              .join(', ');
          return Semantics(
            label: chartSummaryLabel(
              chartType: 'Pie',
              description: 'Water type distribution. $description',
            ),
            child: DistributionPieChart(
              data: data,
              colors: [Colors.blue.shade600, Colors.cyan.shade400],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_conditions_waterType_error,
        ),
      ),
    );
  }

  Widget _buildEntryMethodSection(BuildContext context, WidgetRef ref) {
    final entryMethodAsync = ref.watch(entryMethodDistributionProvider);

    return StatSectionCard(
      title: context.l10n.statistics_conditions_entryMethod_title,
      subtitle: context.l10n.statistics_conditions_entryMethod_subtitle,
      child: entryMethodAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: Icons.directions_boat,
              message: context.l10n.statistics_conditions_entryMethod_empty,
            );
          }
          final chartData = data
              .map((d) => (label: d.label, count: d.count))
              .toList();
          final description = data
              .map((d) => '${d.label}: ${d.count} dives')
              .join(', ');
          return Semantics(
            label: chartSummaryLabel(
              chartType: 'Bar',
              description: 'Entry methods. $description',
            ),
            child: CategoryBarChart(data: chartData, barColor: Colors.teal),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_conditions_entryMethod_error,
        ),
      ),
    );
  }

  Widget _buildTemperatureSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final temperatureAsync = ref.watch(temperatureByMonthProvider);

    return StatSectionCard(
      title: context.l10n.statistics_conditions_temperature_title,
      subtitle: context.l10n.statistics_conditions_temperature_subtitle,
      child: temperatureAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: Icons.thermostat,
              message: context.l10n.statistics_conditions_temperature_empty,
            );
          }

          final months = [
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

          List<TrendDataPoint> toTrendData(double? Function(dynamic) selector) {
            return data.where((d) => selector(d) != null).map((d) {
              return TrendDataPoint(
                date: DateTime(2024, d.month),
                value: selector(d)!,
                label: months[d.month - 1],
              );
            }).toList();
          }

          final minData = toTrendData((d) => d.minTemp);
          final avgData = toTrendData((d) => d.avgTemp);
          final maxData = toTrendData((d) => d.maxTemp);

          return MultiTrendLineChart(
            dataSeries: [minData, avgData, maxData],
            seriesLabels: [
              context.l10n.statistics_conditions_temperature_seriesMin,
              context.l10n.statistics_conditions_temperature_seriesAvg,
              context.l10n.statistics_conditions_temperature_seriesMax,
            ],
            seriesColors: const [Colors.blue, Colors.green, Colors.red],
            valueFormatter: (value) => units.formatTemperature(value),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_conditions_temperature_error,
        ),
      ),
    );
  }
}
