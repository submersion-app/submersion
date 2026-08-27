import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/statistics/domain/career_totals.dart';
import 'package:submersion/features/statistics/presentation/providers/career_totals_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Summary widget shown in the detail pane when no dive is selected.
///
/// Displays aggregate statistics about the user's dive history,
/// including total dives, hours logged, records, and recent activity.
///
/// Dive count and dive time are career totals (logged + prior dives), matching
/// the Statistics overview and the home hero header (issue #808).
class DiveSummaryWidget extends ConsumerWidget {
  const DiveSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diveStatisticsProvider);
    final careerAsync = ref.watch(careerTotalsProvider);
    final recordsAsync = ref.watch(diveRecordsProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            careerAsync.when(
              // careerTotalsProvider awaits diveStatisticsProvider, so stats
              // are resolved by the time career totals are; the null branch is
              // only reachable while a refresh is in flight.
              data: (career) {
                final stats = statsAsync.valueOrNull;
                if (stats == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildStatsSummary(context, stats, career, units);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            const SizedBox(height: 24),
            recordsAsync.when(
              data: (records) => _buildRecordsSection(context, records, units),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.scuba_diving,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.diveLog_summary_title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.diveLog_summary_selectDive,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSummary(
    BuildContext context,
    DiveStatistics stats,
    CareerTotals career,
    UnitFormatter units,
  ) {
    final totalTimeSeconds = career.combinedTimeSeconds;
    final hours = totalTimeSeconds ~/ 3600;
    final minutes = (totalTimeSeconds % 3600) ~/ 60;
    final timeString = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_summary_overview,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context,
              icon: Icons.tag,
              value: '${career.combinedDives}',
              label: context.l10n.diveLog_summary_stat_totalDives,
              subtitle: career.hasPriorDives
                  ? context.l10n.statistics_priorBreakdown(
                      '${career.loggedDives}',
                      '${career.priorDives}',
                    )
                  : null,
              color: Colors.blue,
            ),
            _buildStatCard(
              context,
              icon: Icons.timer,
              value: timeString,
              label: context.l10n.diveLog_summary_stat_diveTime,
              subtitle: career.hasPriorTime
                  ? context.l10n.statistics_priorBreakdown(
                      career.loggedTimeFormatted,
                      career.priorTimeFormatted,
                    )
                  : null,
              color: Colors.teal,
            ),
            _buildStatCard(
              context,
              icon: Icons.arrow_downward,
              value: units.formatDepth(stats.maxDepth),
              label: context.l10n.diveLog_summary_stat_maxDepth,
              color: Colors.indigo,
            ),
            _buildStatCard(
              context,
              icon: Icons.location_on,
              value: '${stats.totalSites}',
              label: context.l10n.diveLog_summary_stat_diveSites,
              color: Colors.orange,
            ),
            if (stats.avgMaxDepth > 0)
              _buildStatCard(
                context,
                icon: Icons.straighten,
                value: units.formatDepth(stats.avgMaxDepth),
                label: context.l10n.diveLog_summary_stat_avgMaxDepth,
                color: Colors.purple,
              ),
            if (stats.avgTemperature != null)
              _buildStatCard(
                context,
                icon: Icons.thermostat,
                value: units.formatTemperature(stats.avgTemperature),
                label: context.l10n.diveLog_summary_stat_avgWaterTemp,
                color: Colors.cyan,
              ),
          ],
        ),
        if (stats.topSites.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildTopSites(context, stats.topSites),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    String? subtitle,
  }) {
    return SizedBox(
      width: 140,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ExcludeSemantics(
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSites(BuildContext context, List<TopSiteStat> topSites) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_summary_section_mostVisited,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: topSites.take(5).map((site) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    '${site.diveCount}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(site.siteName),
                subtitle: Text(
                  context.l10n.diveLog_summary_diveCount(site.diveCount),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/sites/${site.siteId}'),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsSection(
    BuildContext context,
    DiveRecords records,
    UnitFormatter units,
  ) {
    final recordItems = <Widget>[];

    if (records.deepestDive != null && records.deepestDive!.maxDepth != null) {
      recordItems.add(
        _buildRecordItem(
          context,
          units,
          icon: Icons.arrow_downward,
          title: context.l10n.diveLog_summary_record_deepest,
          value: units.formatDepth(records.deepestDive!.maxDepth),
          diveId: records.deepestDive!.diveId,
          date: records.deepestDive!.dateTime,
        ),
      );
    }

    if (records.longestDive != null) {
      final effectiveRuntime = records.longestDive!.effectiveRuntime;
      if (effectiveRuntime != null) {
        recordItems.add(
          _buildRecordItem(
            context,
            units,
            icon: Icons.timer,
            title: context.l10n.diveLog_summary_record_longest,
            value: '${effectiveRuntime.inMinutes} min',
            diveId: records.longestDive!.diveId,
            date: records.longestDive!.dateTime,
          ),
        );
      }
    }

    if (records.coldestDive != null && records.coldestDive!.waterTemp != null) {
      recordItems.add(
        _buildRecordItem(
          context,
          units,
          icon: Icons.ac_unit,
          title: context.l10n.diveLog_summary_record_coldest,
          value: units.formatTemperature(records.coldestDive!.waterTemp),
          diveId: records.coldestDive!.diveId,
          date: records.coldestDive!.dateTime,
        ),
      );
    }

    if (records.warmestDive != null && records.warmestDive!.waterTemp != null) {
      recordItems.add(
        _buildRecordItem(
          context,
          units,
          icon: Icons.wb_sunny,
          title: context.l10n.diveLog_summary_record_warmest,
          value: units.formatTemperature(records.warmestDive!.waterTemp),
          diveId: records.warmestDive!.diveId,
          date: records.warmestDive!.dateTime,
        ),
      );
    }

    if (recordItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_summary_section_records,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(child: Column(children: recordItems)),
      ],
    );
  }

  Widget _buildRecordItem(
    BuildContext context,
    UnitFormatter units, {
    required IconData icon,
    required String title,
    required String value,
    required String diveId,
    required DateTime date,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(units.formatDate(date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        // Use query params to stay in master-detail layout
        final state = GoRouterState.of(context);
        final currentPath = state.uri.path;
        context.go('$currentPath?selected=$diveId');
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_summary_section_quickActions,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                // Use query params to stay in master-detail layout
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                context.go('$currentPath?mode=new');
              },
              icon: const Icon(Icons.edit_note),
              label: Text(
                context.l10n.diveLog_listPage_bottomSheet_logManually,
              ),
            ),
            FilledButton.icon(
              onPressed: () => context.go('/dive-computers'),
              icon: const Icon(Icons.download),
              label: Text(context.l10n.diveLog_summary_action_importComputer),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/statistics'),
              icon: const Icon(Icons.bar_chart),
              label: Text(context.l10n.diveLog_summary_action_viewStats),
            ),
          ],
        ),
      ],
    );
  }
}
