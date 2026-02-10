import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';

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
      appBar: AppBar(title: const Text('Conditions')),
      body: content,
    );
  }

  Widget _buildVisibilitySection(BuildContext context, WidgetRef ref) {
    final visibilityAsync = ref.watch(visibilityDistributionProvider);

    return StatSectionCard(
      title: 'Visibility Distribution',
      subtitle: 'Dives by visibility condition',
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
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load visibility data',
        ),
      ),
    );
  }

  Widget _buildWaterTypeSection(BuildContext context, WidgetRef ref) {
    final waterTypeAsync = ref.watch(waterTypeDistributionProvider);

    return StatSectionCard(
      title: 'Water Type',
      subtitle: 'Salt vs Fresh water dives',
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
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load water type data',
        ),
      ),
    );
  }

  Widget _buildEntryMethodSection(BuildContext context, WidgetRef ref) {
    final entryMethodAsync = ref.watch(entryMethodDistributionProvider);

    return StatSectionCard(
      title: 'Entry Method',
      subtitle: 'Shore, boat, etc.',
      child: entryMethodAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const StatEmptyState(
              icon: Icons.directions_boat,
              message: 'No entry method data available',
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
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load entry method data',
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
      title: 'Water Temperature by Month',
      subtitle: 'Min/Avg/Max temperatures',
      child: temperatureAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const StatEmptyState(
              icon: Icons.thermostat,
              message: 'No temperature data available',
            );
          }

          final months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
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
            seriesLabels: const ['Min', 'Avg', 'Max'],
            seriesColors: const [Colors.blue, Colors.green, Colors.red],
            valueFormatter: (value) => units.formatTemperature(value),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load temperature data',
        ),
      ),
    );
  }
}
