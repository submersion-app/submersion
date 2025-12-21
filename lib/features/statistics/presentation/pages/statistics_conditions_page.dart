import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/repositories/statistics_repository.dart';
import '../providers/statistics_providers.dart';
import '../widgets/stat_charts.dart';
import '../widgets/stat_section_card.dart';

class StatisticsConditionsPage extends ConsumerWidget {
  const StatisticsConditionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conditions'),
      ),
      body: SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildVisibilitySection(BuildContext context, WidgetRef ref) {
    final visibilityAsync = ref.watch(visibilityDistributionProvider);

    return StatSectionCard(
      title: 'Visibility Distribution',
      subtitle: 'Dives by visibility condition',
      child: visibilityAsync.when(
        data: (data) => DistributionPieChart(
          data: data,
          colors: [
            Colors.green.shade400,
            Colors.blue.shade400,
            Colors.orange.shade400,
            Colors.grey.shade400,
          ],
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
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
        data: (data) => DistributionPieChart(
          data: data,
          colors: [
            Colors.blue.shade600,
            Colors.cyan.shade400,
          ],
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
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
          return CategoryBarChart(
            data: data.map((d) => (label: d.label, count: d.count)).toList(),
            barColor: Colors.teal,
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load entry method data',
        ),
      ),
    );
  }

  Widget _buildTemperatureSection(BuildContext context, WidgetRef ref, UnitFormatter units) {
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

          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

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
            seriesColors: [Colors.blue, Colors.green, Colors.red],
            valueFormatter: (value) => units.formatTemperature(value),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load temperature data',
        ),
      ),
    );
  }
}
