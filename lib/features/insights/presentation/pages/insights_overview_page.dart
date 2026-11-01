import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/presentation/insights_dive_filters.dart';
import 'package:submersion/features/insights/presentation/open_chart_dives.dart';
import 'package:submersion/features/insights/presentation/widgets/depth_pie_card.dart';
import 'package:submersion/features/insights/presentation/widgets/distribution_bar_row.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/career_totals.dart';
import 'package:submersion/features/insights/presentation/formatters/distribution_labels.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_overview_empty_state.dart';
import 'package:submersion/features/insights/presentation/widgets/observations_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class InsightsOverviewPage extends ConsumerWidget {
  final bool embedded;

  /// Leads with the observations strip (#2381). On for the desktop summary
  /// pane only: the Overview category detail is the same page and would
  /// otherwise repeat it.
  final bool showObservations;

  const InsightsOverviewPage({
    super.key,
    this.embedded = false,
    this.showObservations = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(filteredDiveStatisticsProvider);

    final body = statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(
        onRetry: () => ref.invalidate(filteredDiveStatisticsProvider),
      ),
      data: (stats) =>
          _OverviewBody(stats: stats, showObservations: showObservations),
    );

    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.insights_category_overview_title),
      ),
      body: body,
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  final DiveStatistics stats;
  final bool showObservations;
  const _OverviewBody({required this.stats, required this.showObservations});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diverAsync = ref.watch(currentDiverProvider);
    // The prior-dive offset is a single lifetime scalar -- no date, site or
    // buddy behind it -- so it cannot be narrowed to a filtered subset. While a
    // filter is active the totals stay logged-only, rather than adding an
    // entire pre-app career on top of (say) one year's dives.
    final filtered = ref.watch(
      insightsFilterProvider.select((f) => f.hasActiveFilters),
    );
    // With no logged dives, whether to show the empty state depends on prior
    // experience -- so wait for the diver to resolve rather than briefly
    // flashing the empty state (currentDiverProvider is a FutureProvider).
    // Irrelevant under a filter, where prior experience is excluded anyway.
    if (stats.totalDives == 0 && !filtered && diverAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final diver = filtered ? null : diverAsync.valueOrNull;
    final career = CareerTotals.from(
      loggedDives: stats.totalDives,
      loggedTimeSeconds: stats.totalTimeSeconds,
      firstLoggedDive: stats.firstDiveDate,
      priorDives: diver?.priorDiveCount,
      priorTimeSeconds: diver?.priorDiveTimeSeconds,
      divingSince: diver?.divingSince,
    );
    // Show the career view when the diver has prior experience even if nothing
    // is logged in-app yet -- otherwise the feature's target user (a long
    // pre-app career, no logged dives) would only ever see the empty state.
    if (stats.totalDives == 0 && !career.hasPriorExperience) {
      // Nothing in scope is not an empty logbook: a filter or an exclusion can
      // empty the scope too. An unknown count must not read as "no dives".
      return ref
          .watch(logbookDiveCountsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorCard(
              onRetry: () => ref.invalidate(logbookDiveCountsProvider),
            ),
            data: (counts) =>
                InsightsOverviewEmptyState(counts: counts, filtered: filtered),
          );
    }

    final fmt = ref.watch(unitFormatterProvider);
    final recordsAsync = ref.watch(filteredDiveRecordsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showObservations)
            const ObservationsStrip(padding: EdgeInsets.only(bottom: 16)),
          _AggregateGrid(stats: stats, fmt: fmt, career: career),
          if (career.divingSinceResolved != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                context.l10n.insights_divingSince(
                  career.divingSinceResolved!.year,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          recordsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => _InlineError(
              message: context.l10n.insights_records_unavailable,
            ),
            data: (records) => _RecordsSection(records: records, fmt: fmt),
          ),
          const SizedBox(height: 16),
          _TopSitesSection(sites: stats.topSites),
          const SizedBox(height: 16),
          _DistributionsSection(stats: stats, fmt: fmt),
          // Explains why the statistics dive count and the logbook dive count
          // differ, so the discrepancy never has to be discovered (#526).
          const ExcludedDivesFootnote(),
        ],
      ),
    );
  }
}

class _AggregateGrid extends StatelessWidget {
  final DiveStatistics stats;
  final UnitFormatter fmt;
  final CareerTotals career;
  const _AggregateGrid({
    required this.stats,
    required this.fmt,
    required this.career,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 600;
    final crossAxis = wide ? 4 : 2;
    final cards = <_StatCard>[
      _StatCard(
        icon: Icons.waves,
        label: context.l10n.insights_summary_totalDives,
        value: '${career.combinedDives}',
        subtitle: career.hasPriorDives
            ? context.l10n.insights_priorBreakdown(
                '${career.loggedDives}',
                '${career.priorDives}',
              )
            : null,
        color: Colors.blue,
      ),
      _StatCard(
        icon: Icons.timer,
        label: context.l10n.insights_summary_totalTime,
        value: career.combinedTimeFormatted,
        subtitle: career.hasPriorTime
            ? context.l10n.insights_priorBreakdown(
                career.loggedTimeFormatted,
                career.priorTimeFormatted,
              )
            : null,
        color: Colors.teal,
      ),
      _StatCard(
        icon: Icons.arrow_downward,
        label: context.l10n.insights_summary_maxDepth,
        value: fmt.formatDepth(stats.maxDepth),
        color: Colors.indigo,
      ),
      _StatCard(
        icon: Icons.straighten,
        label: context.l10n.insights_summary_avgDepth,
        value: fmt.formatDepth(stats.avgMaxDepth),
        color: Colors.purple,
      ),
      if (stats.divesPerMonth != null)
        _StatCard(
          icon: Icons.calendar_month,
          label: context.l10n.insights_summary_divesPerMonth,
          value: stats.divesPerMonth!.toStringAsFixed(1),
          color: Colors.green,
        ),
      if (stats.divesPerYear != null)
        _StatCard(
          icon: Icons.date_range,
          label: context.l10n.insights_summary_divesPerYear,
          value: stats.divesPerYear!.toStringAsFixed(1),
          color: Colors.green.shade700,
        ),
      // This year's actual count beside the lifetime average, which was read
      // as this year's total when it stood alone (issue #2600).
      _StatCard(
        icon: Icons.event_available,
        label: context.l10n.insights_summary_divesThisYear,
        value: '${stats.divesThisYear}',
        color: Colors.lightGreen.shade800,
      ),
      _StatCard(
        icon: Icons.location_on,
        label: context.l10n.insights_summary_sitesVisited,
        value: '${stats.totalSites}',
        color: Colors.orange,
      ),
      if (stats.avgTemperature != null)
        _StatCard(
          icon: Icons.thermostat,
          label: context.l10n.diveLog_summary_stat_avgWaterTemp,
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
  final String? subtitle;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
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
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 2),
            // The card is a fixed square (childAspectRatio 1.0), so a single
            // ellipsized line truncates longer localized labels
            // ("Durchschnittliche Wassertemperatur") down to an unreadable
            // stub. Flexible lets the label use whatever height is left and
            // take a second line when the translation needs one.
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
            Text(context.l10n.insights_error_loadingInsights),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.insights_records_retry),
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
                  context.l10n.diveLog_summary_section_records,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _RecordTile(
                icon: Icons.flag,
                label: context.l10n.insights_records_firstDive,
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
          label: context.l10n.insights_records_deepestDive,
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
          label: context.l10n.insights_records_longestDive,
          value: context.l10n.insights_records_longestDiveValue(minutes),
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
          label: context.l10n.insights_records_coldestDive,
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
          label: context.l10n.insights_records_warmestDive,
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
                context.l10n.diveLog_summary_section_records,
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
                context.l10n.diveLog_summary_section_mostVisited,
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
                subtitle: Text(
                  context.l10n.insights_summary_tagUsage_diveCount(
                    site.diveCount,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/sites/${site.siteId}'),
              ),
          ],
        ),
      ),
    );
  }
}

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
    final typesById = watchDiveTypesById(ref);

    Future<void> openDepth(int bucket) => openChartDives(
      context,
      ref,
      chart: context.l10n.insights_summary_depthDistribution_title,
      row: depthBucketLabel(stats.depthDistribution[bucket], fmt, context.l10n),
      load: (repository, diverId, scope) => repository.getDepthBucketDiveIds(
        bucket: bucket,
        diverId: diverId,
        filter: scope,
      ),
    );
    final depthChart = DepthPieCard(
      onOpenBucket: openDepth,
      depthDistribution: stats.depthDistribution,
      fmt: fmt,
    );

    // Dive types get no pie (issue #3048): a dive can carry several types and
    // counts once under each, so the per-type counts sum to more than the
    // number of dives and a pie's slices would not be shares of anything.
    // Each type's count and summed dive time (issue #641) is listed in full
    // as a bar row instead, sized against the most common type.
    final typeStats = diveTypesAsync.maybeWhen(
      data: (diveTypes) => diveTypes,
      orElse: () => const <DistributionSegment>[],
    );
    final typeMaxCount = typeStats.isEmpty
        ? 0
        : typeStats.map((t) => t.count).reduce((a, b) => a > b ? a : b);
    final typeStatus = diveTypesAsync.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) =>
          _InlineError(message: context.l10n.insights_summary_diveTypes_error),
      // Dives exist (this section is hidden otherwise) but none carries a
      // type: say so rather than dropping the section without a word.
      data: (diveTypes) => diveTypes.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                context.l10n.insights_chart_noBarData,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : null,
    );

    // Depth buckets get the same full bar list: every bucket that has a dive
    // in it, with its count and summed dive time, regardless of how many the
    // pie's own legend can fit (issue #641 follow-up). The original index into
    // the (always 14-entry) depthDistribution list is kept so each bar can
    // reuse the same _depthColors entry as its pie slice.
    final depthEntries = [
      for (final (index, segment) in stats.depthDistribution.indexed)
        if (segment.count > 0) (index, segment),
    ];
    final depthMaxCount = depthEntries.isEmpty
        ? 0
        : depthEntries.map((e) => e.$2.count).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                context.l10n.insights_summary_distributions_title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            depthChart,
            if (depthEntries.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  context.l10n.insights_summary_depthDistribution_title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final (index, segment) in depthEntries)
                DistributionBarRow(
                  label: depthBucketLabel(segment, fmt, context.l10n),
                  count: segment.count,
                  totalDurationSeconds: segment.totalDurationSeconds,
                  color: depthBucketColors[index % depthBucketColors.length],
                  fraction: depthMaxCount == 0
                      ? 0
                      : segment.count / depthMaxCount,
                  fillKey: ValueKey('depth-bar-fill-$index'),
                  onTap: () => openDepth(index),
                ),
            ],
            if (typeStatus != null || typeStats.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  context.l10n.insights_summary_diveTypes_title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ?typeStatus,
              for (final (index, segment) in typeStats.indexed)
                DistributionBarRow(
                  label: diveTypeDistributionLabel(
                    segment.label,
                    context.l10n,
                    typesById: typesById,
                  ),
                  count: segment.count,
                  onTap: () => openFilteredChartDives(
                    context,
                    ref,
                    chart: context.l10n.insights_summary_diveTypes_title,
                    row: diveTypeDistributionLabel(
                      segment.label,
                      context.l10n,
                      typesById: typesById,
                    ),
                    narrow: (scope) =>
                        diveTypeDivesFilter(scope, segment.label),
                  ),
                  totalDurationSeconds: segment.totalDurationSeconds,
                  color: _typeColors[index % _typeColors.length],
                  fraction: typeMaxCount == 0
                      ? 0
                      : segment.count / typeMaxCount,
                  fillKey: ValueKey('type-bar-fill-$index'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
