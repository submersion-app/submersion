import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class StatisticsOverviewPage extends ConsumerWidget {
  final bool embedded;
  const StatisticsOverviewPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diveStatisticsProvider);

    final body = statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          _ErrorCard(onRetry: () => ref.invalidate(diveStatisticsProvider)),
      data: (stats) => _OverviewBody(stats: stats),
    );

    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: body,
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  final DiveStatistics stats;
  const _OverviewBody({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final fmt = UnitFormatter(settings);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_AggregateGrid(stats: stats, fmt: fmt)],
      ),
    );
  }
}

class _AggregateGrid extends StatelessWidget {
  final DiveStatistics stats;
  final UnitFormatter fmt;
  const _AggregateGrid({required this.stats, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 600;
    final crossAxis = wide ? 4 : 2;
    final cards = <_StatCard>[
      _StatCard(label: 'Total Dives', value: '${stats.totalDives}'),
      _StatCard(
        label: 'Total Time',
        value: _formatDuration(stats.totalTimeSeconds),
      ),
      _StatCard(label: 'Max Depth', value: fmt.formatDepth(stats.maxDepth)),
      _StatCard(label: 'Avg Depth', value: fmt.formatDepth(stats.avgMaxDepth)),
      if (stats.divesPerMonth != null)
        _StatCard(
          label: 'Dives / Month',
          value: stats.divesPerMonth!.toStringAsFixed(1),
        ),
      if (stats.divesPerYear != null)
        _StatCard(
          label: 'Dives / Year',
          value: stats.divesPerYear!.toStringAsFixed(1),
        ),
      _StatCard(label: 'Sites Visited', value: '${stats.totalSites}'),
      if (stats.avgTemperature != null)
        _StatCard(
          label: 'Avg Water Temp',
          value: fmt.formatTemperature(stats.avgTemperature!),
        ),
    ];

    return GridView.count(
      crossAxisCount: crossAxis,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: cards,
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text("Couldn't load statistics"),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
