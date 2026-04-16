import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
    final recordsAsync = ref.watch(diveRecordsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AggregateGrid(stats: stats, fmt: fmt),
          const SizedBox(height: 16),
          recordsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) =>
                const _InlineError(message: 'Records unavailable'),
            data: (records) => _RecordsSection(records: records, fmt: fmt),
          ),
        ],
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
      _StatCard(label: 'Total Time', value: stats.totalTimeFormatted),
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
            Text(context.l10n.statistics_error_loadingStatistics),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.statistics_records_retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordsSection extends StatelessWidget {
  final DiveRecords records;
  final UnitFormatter fmt;
  const _RecordsSection({required this.records, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (records.deepestDive != null) {
      rows.add(
        _RecordTile(
          label: 'Deepest Dive',
          value: fmt.formatDepth(records.deepestDive!.maxDepth),
          subtitle: _dateLabel(records.deepestDive!.dateTime),
          onTap: () => context.go('/dives/${records.deepestDive!.diveId}'),
        ),
      );
    }
    if (records.longestDive != null) {
      rows.add(
        _RecordTile(
          label: 'Longest Dive',
          value: _formatDuration(records.longestDive!.effectiveRuntime),
          subtitle: _dateLabel(records.longestDive!.dateTime),
          onTap: () => context.go('/dives/${records.longestDive!.diveId}'),
        ),
      );
    }
    if (records.coldestDive != null) {
      rows.add(
        _RecordTile(
          label: 'Coldest Dive',
          value: fmt.formatTemperature(records.coldestDive!.waterTemp ?? 0),
          subtitle: _dateLabel(records.coldestDive!.dateTime),
          onTap: () => context.go('/dives/${records.coldestDive!.diveId}'),
        ),
      );
    }
    if (records.warmestDive != null) {
      rows.add(
        _RecordTile(
          label: 'Warmest Dive',
          value: fmt.formatTemperature(records.warmestDive!.waterTemp ?? 0),
          subtitle: _dateLabel(records.warmestDive!.dateTime),
          onTap: () => context.go('/dives/${records.warmestDive!.diveId}'),
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Personal Records',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class _RecordTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final VoidCallback onTap;
  const _RecordTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
