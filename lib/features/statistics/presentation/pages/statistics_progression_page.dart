import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/statistics_providers.dart';
import '../widgets/stat_charts.dart';
import '../widgets/stat_section_card.dart';

class StatisticsProgressionPage extends ConsumerWidget {
  const StatisticsProgressionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Progression'),
      ),
      body: SingleChildScrollView(
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
            _buildCumulativeSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildDepthProgressionSection(BuildContext context, WidgetRef ref, UnitFormatter units) {
    final depthTrendAsync = ref.watch(depthProgressionTrendProvider);

    return StatSectionCard(
      title: 'Maximum Depth Progression',
      subtitle: 'Monthly max depth over 5 years',
      child: depthTrendAsync.when(
        data: (data) => TrendLineChart(
          data: data,
          lineColor: Colors.indigo,
          valueFormatter: (value) => units.formatDepth(value),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load depth progression',
        ),
      ),
    );
  }

  Widget _buildBottomTimeSection(BuildContext context, WidgetRef ref) {
    final bottomTimeAsync = ref.watch(bottomTimeTrendProvider);

    return StatSectionCard(
      title: 'Bottom Time Trend',
      subtitle: 'Average duration by month',
      child: bottomTimeAsync.when(
        data: (data) => TrendLineChart(
          data: data,
          lineColor: Colors.teal,
          valueFormatter: (value) => '${value.toStringAsFixed(0)} min',
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load bottom time trend',
        ),
      ),
    );
  }

  Widget _buildDivesPerYearSection(BuildContext context, WidgetRef ref) {
    final divesPerYearAsync = ref.watch(divesPerYearProvider);

    return StatSectionCard(
      title: 'Dives Per Year',
      subtitle: 'Annual dive count comparison',
      child: divesPerYearAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const StatEmptyState(
              icon: Icons.bar_chart,
              message: 'No yearly data available',
            );
          }
          return CategoryBarChart(
            data: data.map((d) => (label: '${d.year}', count: d.count)).toList(),
            barColor: Theme.of(context).colorScheme.primary,
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load yearly data',
        ),
      ),
    );
  }

  Widget _buildCumulativeSection(BuildContext context, WidgetRef ref) {
    final cumulativeAsync = ref.watch(cumulativeDiveCountProvider);

    return StatSectionCard(
      title: 'Cumulative Dive Count',
      subtitle: 'Total dives over time',
      child: cumulativeAsync.when(
        data: (data) => TrendLineChart(
          data: data,
          lineColor: Colors.green,
          valueFormatter: (value) => value.toStringAsFixed(0),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load cumulative data',
        ),
      ),
    );
  }
}
