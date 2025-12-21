import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../dive_log/data/repositories/dive_repository_impl.dart';
import '../../../dive_log/presentation/providers/dive_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../tags/presentation/providers/tag_providers.dart';
import '../widgets/stat_section_card.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diveStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Dive Records',
            onPressed: () => context.push('/records'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(diveStatisticsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) => _buildContent(context, ref, stats),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              const Text('Error loading statistics'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(diveStatisticsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, DiveStatistics stats) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewCards(context, stats, units),
          const SizedBox(height: 24),
          _buildCategoryCards(context),
          const SizedBox(height: 24),
          _buildDivesByMonthChart(context, stats),
          const SizedBox(height: 24),
          _buildDepthDistribution(context, stats, units),
          const SizedBox(height: 24),
          _buildTopSites(context, stats),
          const SizedBox(height: 24),
          _buildTagStatistics(context),
        ],
      ),
    );
  }

  Widget _buildCategoryCards(BuildContext context) {
    final categories = [
      (
        icon: Icons.air,
        title: 'Air Consumption',
        subtitle: 'SAC rates & gas mixes',
        color: Colors.blue,
        route: '/statistics/gas',
      ),
      (
        icon: Icons.trending_up,
        title: 'Progression',
        subtitle: 'Depth & time trends',
        color: Colors.green,
        route: '/statistics/progression',
      ),
      (
        icon: Icons.thermostat,
        title: 'Conditions',
        subtitle: 'Visibility & temperature',
        color: Colors.orange,
        route: '/statistics/conditions',
      ),
      (
        icon: Icons.people,
        title: 'Social',
        subtitle: 'Buddies & dive centers',
        color: Colors.purple,
        route: '/statistics/social',
      ),
      (
        icon: Icons.public,
        title: 'Geographic',
        subtitle: 'Countries & regions',
        color: Colors.teal,
        route: '/statistics/geographic',
      ),
      (
        icon: Icons.pets,
        title: 'Marine Life',
        subtitle: 'Species sightings',
        color: Colors.cyan,
        route: '/statistics/marine-life',
      ),
      (
        icon: Icons.schedule,
        title: 'Time Patterns',
        subtitle: 'When you dive',
        color: Colors.amber,
        route: '/statistics/time-patterns',
      ),
      (
        icon: Icons.build,
        title: 'Equipment',
        subtitle: 'Gear usage & weight',
        color: Colors.brown,
        route: '/statistics/equipment',
      ),
      (
        icon: Icons.show_chart,
        title: 'Profile Analysis',
        subtitle: 'Ascent rates & deco',
        color: Colors.indigo,
        route: '/statistics/profile',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore Statistics',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return StatCategoryCard(
              icon: cat.icon,
              title: cat.title,
              subtitle: cat.subtitle,
              color: cat.color,
              onTap: () => context.push(cat.route),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOverviewCards(BuildContext context, DiveStatistics stats, UnitFormatter units) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _buildStatCard(
          context,
          icon: Icons.waves,
          label: 'Total Dives',
          value: '${stats.totalDives}',
          color: Theme.of(context).colorScheme.primary,
        ),
        _buildStatCard(
          context,
          icon: Icons.timer,
          label: 'Total Time',
          value: stats.totalTimeFormatted,
          color: Theme.of(context).colorScheme.secondary,
        ),
        _buildStatCard(
          context,
          icon: Icons.arrow_downward,
          label: 'Max Depth',
          value: stats.maxDepth > 0 ? units.formatDepth(stats.maxDepth) : '--',
          color: Theme.of(context).colorScheme.tertiary,
        ),
        _buildStatCard(
          context,
          icon: Icons.location_on,
          label: 'Sites Visited',
          value: '${stats.totalSites}',
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildDivesByMonthChart(BuildContext context, DiveStatistics stats) {
    final hasData = stats.divesByMonth.isNotEmpty;
    final maxCount = hasData
        ? stats.divesByMonth.map((e) => e.count).reduce((a, b) => a > b ? a : b).toDouble()
        : 5.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dives by Month',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: hasData
                  ? BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxCount + 1,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final data = stats.divesByMonth[groupIndex];
                              return BarTooltipItem(
                                '${data.fullLabel}\n${data.count} dives',
                                TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < stats.divesByMonth.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      stats.divesByMonth[index].label,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value == value.roundToDouble()) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            strokeWidth: 1,
                          ),
                        ),
                        barGroups: List.generate(
                          stats.divesByMonth.length,
                          (index) => BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: stats.divesByMonth[index].count.toDouble(),
                                color: Theme.of(context).colorScheme.primary,
                                width: 16,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Chart will appear when you log dives',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepthDistribution(BuildContext context, DiveStatistics stats, UnitFormatter units) {
    final hasData = stats.depthDistribution.any((d) => d.count > 0);
    final colors = [
      Colors.lightBlue.shade300,
      Colors.blue.shade400,
      Colors.blue.shade600,
      Colors.indigo.shade600,
      Colors.indigo.shade900,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Depth Distribution',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: hasData
                  ? Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 30,
                              sections: List.generate(
                                stats.depthDistribution.length,
                                (index) {
                                  final data = stats.depthDistribution[index];
                                  if (data.count == 0) return null;
                                  return PieChartSectionData(
                                    value: data.count.toDouble(),
                                    title: '${data.count}',
                                    color: colors[index % colors.length],
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ).whereType<PieChartSectionData>().toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(
                              stats.depthDistribution.length,
                              (index) {
                                final data = stats.depthDistribution[index];
                                // Convert depth range labels to user's preferred unit
                                final minDisplay = units.convertDepth(data.minDepth.toDouble()).round();
                                final maxDisplay = units.convertDepth(data.maxDepth.toDouble()).round();
                                final label = data.maxDepth >= 100
                                    ? '$minDisplay${units.depthSymbol}+'
                                    : '$minDisplay-$maxDisplay${units.depthSymbol}';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: colors[index % colors.length],
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: Theme.of(context).textTheme.bodySmall,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pie_chart,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Chart will appear when you log dives',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (hasData) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMiniStat(context, 'Avg Depth', units.formatDepth(stats.avgMaxDepth)),
                  if (stats.avgTemperature != null)
                    _buildMiniStat(context, 'Avg Temp', units.formatTemperature(stats.avgTemperature)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildTopSites(BuildContext context, DiveStatistics stats) {
    final hasData = stats.topSites.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Dive Sites',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (stats.totalSites > 0)
                  Text(
                    '${stats.totalSites} total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            const Divider(),
            if (hasData)
              ...stats.topSites.asMap().entries.map((entry) {
                final index = entry.key;
                final site = entry.value;
                return _buildSiteRankTile(context, index + 1, site.siteName, site.diveCount);
              })
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No dive sites yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteRankTile(BuildContext context, int rank, String siteName, int diveCount) {
    final rankColors = [
      Colors.amber.shade600,
      Colors.grey.shade400,
      Colors.brown.shade400,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank <= 3 ? rankColors[rank - 1] : Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank <= 3 ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              siteName,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$diveCount dives',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagStatistics(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final tagStatsAsync = ref.watch(tagStatisticsProvider);

        return tagStatsAsync.when(
          data: (tagStats) {
            if (tagStats.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tag Usage',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.label_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No tags created yet',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add tags to dives to see statistics',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final maxCount = tagStats.map((s) => s.diveCount).reduce((a, b) => a > b ? a : b);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tag Usage',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${tagStats.length} tags',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const Divider(),
                    ...tagStats.take(10).map((stat) => _buildTagStatTile(
                          context,
                          stat.tag.name,
                          stat.diveCount,
                          stat.tag.color,
                          maxCount,
                        ),),
                    if (tagStats.length > 10) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'and ${tagStats.length - 10} more tags',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildTagStatTile(
    BuildContext context,
    String tagName,
    int diveCount,
    Color color,
    int maxCount,
  ) {
    final percentage = maxCount > 0 ? diveCount / maxCount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tagName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '$diveCount ${diveCount == 1 ? 'dive' : 'dives'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: color.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
