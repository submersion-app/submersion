import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/statistics_providers.dart';
import '../widgets/stat_charts.dart';
import '../widgets/stat_section_card.dart';

class StatisticsProfilePage extends ConsumerWidget {
  const StatisticsProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Analysis'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAscentDescentSection(context, ref, units),
            const SizedBox(height: 16),
            _buildTimeAtDepthSection(context, ref),
            const SizedBox(height: 16),
            _buildDecoSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildAscentDescentSection(BuildContext context, WidgetRef ref, UnitFormatter units) {
    final ratesAsync = ref.watch(ascentDescentRatesProvider);

    return StatSectionCard(
      title: 'Average Ascent & Descent Rates',
      subtitle: 'From dive profile data',
      child: ratesAsync.when(
        data: (data) {
          if (data.avgAscent == null && data.avgDescent == null) {
            return const StatEmptyState(
              icon: Icons.trending_up,
              message: 'No profile data available',
            );
          }

          return Row(
            children: [
              if (data.avgAscent != null)
                Expanded(
                  child: _buildRateStat(
                    context,
                    'Avg Ascent',
                    '${units.convertDepth(data.avgAscent!).toStringAsFixed(1)} ${units.depthSymbol}/min',
                    Icons.arrow_upward,
                    Colors.green,
                  ),
                ),
              if (data.avgAscent != null && data.avgDescent != null)
                const SizedBox(width: 16),
              if (data.avgDescent != null)
                Expanded(
                  child: _buildRateStat(
                    context,
                    'Avg Descent',
                    '${units.convertDepth(data.avgDescent!).toStringAsFixed(1)} ${units.depthSymbol}/min',
                    Icons.arrow_downward,
                    Colors.blue,
                  ),
                ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load rate data',
        ),
      ),
    );
  }

  Widget _buildRateStat(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAtDepthSection(BuildContext context, WidgetRef ref) {
    final depthRangesAsync = ref.watch(timeAtDepthRangesProvider);

    return StatSectionCard(
      title: 'Time at Depth Ranges',
      subtitle: 'Approximate time spent at each depth',
      child: depthRangesAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const StatEmptyState(
              icon: Icons.layers,
              message: 'No depth data available',
            );
          }
          return CategoryBarChart(
            data: data.map((d) => (label: d.range, count: d.minutes)).toList(),
            barColor: Colors.indigo,
            valueFormatter: (value) => '$value min',
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load depth range data',
        ),
      ),
    );
  }

  Widget _buildDecoSection(BuildContext context, WidgetRef ref) {
    final decoAsync = ref.watch(decoObligationStatsProvider);

    return StatSectionCard(
      title: 'Decompression Obligation',
      subtitle: 'Dives that incurred deco stops',
      child: decoAsync.when(
        data: (data) {
          if (data.totalCount == 0) {
            return const StatEmptyState(
              icon: Icons.stop_circle,
              message: 'No deco data available',
            );
          }

          final percentage = data.decoCount / data.totalCount * 100;

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDecoStat(
                    context,
                    'Deco Dives',
                    data.decoCount.toString(),
                    Colors.orange,
                  ),
                  _buildDecoStat(
                    context,
                    'No Deco',
                    (data.totalCount - data.decoCount).toString(),
                    Colors.green,
                  ),
                  _buildDecoStat(
                    context,
                    'Deco Rate',
                    '${percentage.toStringAsFixed(1)}%',
                    Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.green.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.orange),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'No Deco',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                  ),
                  Text(
                    'Deco',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load deco data',
        ),
      ),
    );
  }

  Widget _buildDecoStat(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
