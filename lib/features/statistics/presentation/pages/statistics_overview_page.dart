import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
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
      appBar: AppBar(
        title: Text(context.l10n.statistics_category_overview_title),
      ),
      body: body,
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  final DiveStatistics stats;
  const _OverviewBody({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stats.totalDives == 0) {
      return const _EmptyState();
    }

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
          const SizedBox(height: 16),
          _TopSitesSection(sites: stats.topSites),
          const SizedBox(height: 16),
          _DistributionsSection(stats: stats, fmt: fmt),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('No dives logged yet'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => context.push('/dives/new'),
                  child: const Text('Log a Dive'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => context.push('/transfer/import-wizard'),
                  child: const Text('Import Dives'),
                ),
              ],
            ),
          ],
        ),
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
      _StatCard(
        icon: Icons.waves,
        label: 'Total Dives',
        value: '${stats.totalDives}',
        color: Colors.blue,
      ),
      _StatCard(
        icon: Icons.timer,
        label: 'Total Time',
        value: stats.totalTimeFormatted,
        color: Colors.teal,
      ),
      _StatCard(
        icon: Icons.arrow_downward,
        label: 'Max Depth',
        value: fmt.formatDepth(stats.maxDepth),
        color: Colors.indigo,
      ),
      _StatCard(
        icon: Icons.straighten,
        label: 'Avg Depth',
        value: fmt.formatDepth(stats.avgMaxDepth),
        color: Colors.purple,
      ),
      if (stats.divesPerMonth != null)
        _StatCard(
          icon: Icons.calendar_month,
          label: 'Dives / Month',
          value: stats.divesPerMonth!.toStringAsFixed(1),
          color: Colors.green,
        ),
      if (stats.divesPerYear != null)
        _StatCard(
          icon: Icons.date_range,
          label: 'Dives / Year',
          value: stats.divesPerYear!.toStringAsFixed(1),
          color: Colors.green.shade700,
        ),
      _StatCard(
        icon: Icons.location_on,
        label: 'Sites Visited',
        value: '${stats.totalSites}',
        color: Colors.orange,
      ),
      if (stats.avgTemperature != null)
        _StatCard(
          icon: Icons.thermostat,
          label: 'Avg Water Temp',
          value: fmt.formatTemperature(stats.avgTemperature!),
          color: Colors.cyan,
        ),
    ];

    return GridView.count(
      crossAxisCount: crossAxis,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: cards,
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    // Single-dive collapse: if multiple record slots all point to the same
    // dive, show one summary row instead of repeating the same dive.
    final nonNullRecords = [
      records.deepestDive,
      records.longestDive,
      records.coldestDive,
      records.warmestDive,
    ].whereType<DiveRecord>().toList();
    final uniqueIds = nonNullRecords.map((r) => r.diveId).toSet();

    if (nonNullRecords.length >= 2 && uniqueIds.length == 1) {
      final record = nonNullRecords.first;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Personal Records',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _RecordTile(
                icon: Icons.flag,
                label: 'First Dive',
                value: fmt.formatDepth(record.maxDepth),
                subtitle: fmt.formatDate(record.dateTime),
                color: Colors.blue,
                onTap: () => context.push('/dives/${record.diveId}'),
              ),
            ],
          ),
        ),
      );
    }

    final rows = <Widget>[];
    if (records.deepestDive != null) {
      rows.add(
        _RecordTile(
          icon: Icons.arrow_downward,
          label: 'Deepest Dive',
          value: fmt.formatDepth(records.deepestDive!.maxDepth),
          subtitle: fmt.formatDate(records.deepestDive!.dateTime),
          color: Colors.indigo,
          onTap: () => context.push('/dives/${records.deepestDive!.diveId}'),
        ),
      );
    }
    if (records.longestDive != null) {
      final minutes = records.longestDive!.effectiveRuntime?.inMinutes ?? 0;
      rows.add(
        _RecordTile(
          icon: Icons.timer,
          label: 'Longest Dive',
          value: context.l10n.statistics_records_longestDiveValue(minutes),
          subtitle: fmt.formatDate(records.longestDive!.dateTime),
          color: Colors.teal,
          onTap: () => context.push('/dives/${records.longestDive!.diveId}'),
        ),
      );
    }
    if (records.coldestDive != null) {
      rows.add(
        _RecordTile(
          icon: Icons.ac_unit,
          label: 'Coldest Dive',
          value: fmt.formatTemperature(records.coldestDive!.waterTemp),
          subtitle: fmt.formatDate(records.coldestDive!.dateTime),
          color: Colors.blue,
          onTap: () => context.push('/dives/${records.coldestDive!.diveId}'),
        ),
      );
    }
    if (records.warmestDive != null) {
      rows.add(
        _RecordTile(
          icon: Icons.whatshot,
          label: 'Warmest Dive',
          value: fmt.formatTemperature(records.warmestDive!.waterTemp),
          subtitle: fmt.formatDate(records.warmestDive!.dateTime),
          color: Colors.orange,
          onTap: () => context.push('/dives/${records.warmestDive!.diveId}'),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Personal Records',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _RecordTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
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

class _TopSitesSection extends StatelessWidget {
  final List<TopSiteStat> sites;
  const _TopSitesSection({required this.sites});

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Most Visited Sites',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            for (final site in sites.take(5))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(site.siteName),
                subtitle: Text('${site.diveCount} dives'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/sites/${site.siteId}'),
              ),
          ],
        ),
      ),
    );
  }
}

const _depthColors = [
  Color(0xFF4FC3F7), // lightBlue.shade300
  Color(0xFF42A5F5), // blue.shade400
  Color(0xFF1E88E5), // blue.shade600
  Color(0xFF3949AB), // indigo.shade600
  Color(0xFF1A237E), // indigo.shade900
];

const _typeColors = [
  Color(0xFF42A5F5), // blue.shade400
  Color(0xFF26A69A), // teal.shade400
  Color(0xFFFFA726), // orange.shade400
  Color(0xFFAB47BC), // purple.shade400
  Color(0xFF66BB6A), // green.shade400
  Color(0xFFEF5350), // red.shade400
  Color(0xFF5C6BC0), // indigo.shade400
  Color(0xFFFFCA28), // amber.shade400
];

class _DistributionsSection extends ConsumerWidget {
  final DiveStatistics stats;
  final UnitFormatter fmt;
  const _DistributionsSection({required this.stats, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diveTypesAsync = ref.watch(diveTypeDistributionProvider);

    final depthChart = _DepthPieCard(
      depthDistribution: stats.depthDistribution,
      fmt: fmt,
    );

    final typeChart = diveTypesAsync.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) =>
          const _InlineError(message: 'Unable to load dive type data'),
      data: (diveTypes) => _TypePieCard(diveTypes: diveTypes),
    );

    final wide = MediaQuery.of(context).size.width >= 600;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Distributions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: depthChart),
                  const SizedBox(width: 8),
                  Expanded(child: typeChart),
                ],
              )
            else
              Column(
                children: [depthChart, const SizedBox(height: 8), typeChart],
              ),
          ],
        ),
      ),
    );
  }
}

class _DepthPieCard extends StatelessWidget {
  final List<DepthRangeStat> depthDistribution;
  final UnitFormatter fmt;
  const _DepthPieCard({required this.depthDistribution, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final nonEmpty = depthDistribution.where((d) => d.count > 0).toList();
    final hasData = nonEmpty.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.statistics_summary_depthDistribution_title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: hasData
              ? Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Semantics(
                        label: context
                            .l10n
                            .statistics_summary_depthDistribution_semanticLabel,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 24,
                            sections: List.generate(depthDistribution.length, (
                              index,
                            ) {
                              final data = depthDistribution[index];
                              if (data.count == 0) return null;
                              return PieChartSectionData(
                                value: data.count.toDouble(),
                                title: '${data.count}',
                                color:
                                    _depthColors[index % _depthColors.length],
                                radius: 50,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              );
                            }).whereType<PieChartSectionData>().toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: () {
                          final nonEmptyEntries = <(int, DepthRangeStat)>[];
                          for (var i = 0; i < depthDistribution.length; i++) {
                            if (depthDistribution[i].count > 0) {
                              nonEmptyEntries.add((i, depthDistribution[i]));
                            }
                          }
                          return nonEmptyEntries.map((
                            (int, DepthRangeStat) entry,
                          ) {
                            final index = entry.$1;
                            final data = entry.$2;
                            final minDisplay = fmt
                                .convertDepth(data.minDepth.toDouble())
                                .round();
                            final maxDisplay = fmt
                                .convertDepth(data.maxDepth.toDouble())
                                .round();
                            final label = data.maxDepth >= 100
                                ? '$minDisplay${fmt.depthSymbol}+'
                                : '$minDisplay-$maxDisplay${fmt.depthSymbol}';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color:
                                          _depthColors[index %
                                              _depthColors.length],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        }(),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(
                    Icons.pie_chart_outline,
                    size: 40,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TypePieCard extends StatelessWidget {
  final List<DistributionSegment> diveTypes;
  const _TypePieCard({required this.diveTypes});

  @override
  Widget build(BuildContext context) {
    final hasData = diveTypes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.statistics_summary_diveTypes_title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: hasData
              ? Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Semantics(
                        label: context
                            .l10n
                            .statistics_summary_diveTypes_semanticLabel,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 24,
                            sections: List.generate(diveTypes.length, (index) {
                              final segment = diveTypes[index];
                              return PieChartSectionData(
                                value: segment.count.toDouble(),
                                title:
                                    '${segment.percentage.toStringAsFixed(0)}%',
                                color: _typeColors[index % _typeColors.length],
                                radius: 50,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          diveTypes.length > 6 ? 6 : diveTypes.length,
                          (index) {
                            final segment = diveTypes[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color:
                                          _typeColors[index %
                                              _typeColors.length],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      segment.label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(
                    Icons.pie_chart_outline,
                    size: 40,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
        ),
      ],
    );
  }
}
