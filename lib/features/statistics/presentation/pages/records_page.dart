import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Full-page personal records, reached from the Statistics tab's trophy
/// action. Scoped by the Statistics filter (issue #1028) so it agrees with the
/// records card on the overview page one tap behind it; the filter bar keeps
/// the narrowed scope visible and clearable here too.
class RecordsPage extends ConsumerWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(filteredDiveRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statistics_records_appBar_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.statistics_tooltip_refreshRecords,
            onPressed: () => ref.invalidate(filteredDiveRecordsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          const StatisticsFilterBar(),
          Expanded(
            child: recordsAsync.when(
              data: (records) => _buildContent(context, ref, records),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(context.l10n.statistics_records_error),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(filteredDiveRecordsProvider),
                      child: Text(context.l10n.statistics_records_retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DiveRecords records,
  ) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // Every slot the page can render, not just the four superlative cards:
    // firstDive/lastDive carry no field predicate, so dives logged with only a
    // date populate the milestones while all four superlatives stay null.
    // Gating on the four alone hid milestone cards that had content.
    final hasRecords = [
      records.deepestDive,
      records.longestDive,
      records.coldestDive,
      records.warmestDive,
      records.shallowestDive,
      records.firstDive,
      records.lastDive,
    ].any((record) => record != null);

    if (!hasRecords) {
      // "Start logging dives" is wrong advice when the logbook is full and the
      // filter is simply too narrow, so the filtered case gets the dive list's
      // wording instead.
      final filtered = ref.watch(
        statisticsFilterProvider.select((f) => f.hasActiveFilters),
      );
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filtered ? Icons.filter_list_off : Icons.emoji_events_outlined,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              filtered
                  ? context.l10n.diveLog_emptyFiltered_title
                  : context.l10n.statistics_records_emptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? context.l10n.diveLog_emptyFiltered_subtitle
                  : context.l10n.statistics_records_emptySubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (records.deepestDive != null)
          _buildRecordCard(
            context,
            units,
            title: context.l10n.statistics_records_deepestDive,
            icon: Icons.arrow_downward,
            color: Colors.blue,
            record: records.deepestDive!,
            value: units.formatDepth(records.deepestDive!.maxDepth),
          ),
        if (records.longestDive != null)
          _buildRecordCard(
            context,
            units,
            title: context.l10n.statistics_records_longestDive,
            icon: Icons.timer,
            color: Colors.green,
            record: records.longestDive!,
            value: context.l10n.statistics_records_longestDiveValue(
              records.longestDive!.effectiveRuntime?.inMinutes ?? 0,
            ),
          ),
        if (records.coldestDive != null)
          _buildRecordCard(
            context,
            units,
            title: context.l10n.statistics_records_coldestDive,
            icon: Icons.ac_unit,
            color: Colors.cyan,
            record: records.coldestDive!,
            value: units.formatTemperature(records.coldestDive!.waterTemp),
          ),
        if (records.warmestDive != null)
          _buildRecordCard(
            context,
            units,
            title: context.l10n.statistics_records_warmestDive,
            icon: Icons.whatshot,
            color: Colors.orange,
            record: records.warmestDive!,
            value: units.formatTemperature(records.warmestDive!.waterTemp),
          ),
        if (records.shallowestDive != null)
          _buildRecordCard(
            context,
            units,
            title: context.l10n.statistics_records_shallowestDive,
            icon: Icons.arrow_upward,
            color: Colors.teal,
            record: records.shallowestDive!,
            value: units.formatDepth(records.shallowestDive!.maxDepth),
          ),
        const SizedBox(height: 24),
        Text(
          context.l10n.statistics_records_milestones,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (records.firstDive != null)
          _buildMilestoneCard(
            context,
            units,
            title: context.l10n.statistics_records_firstDive,
            icon: Icons.flag,
            color: Colors.purple,
            record: records.firstDive!,
          ),
        if (records.lastDive != null)
          _buildMilestoneCard(
            context,
            units,
            title: context.l10n.statistics_records_mostRecentDive,
            icon: Icons.update,
            color: Colors.indigo,
            record: records.lastDive!,
          ),
      ],
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    UnitFormatter units, {
    required String title,
    required IconData icon,
    required Color color,
    required DiveRecord record,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: context.l10n.statistics_records_recordSemanticLabel(
          title,
          value,
          record.siteName ?? context.l10n.statistics_records_unknownSite,
        ),
        child: InkWell(
          onTap: () => context.push('/dives/${record.diveId}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.siteName ??
                            context.l10n.statistics_records_unknownSite,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        units.formatDate(record.dateTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (record.diveNumber != null)
                        Text(
                          context.l10n.statistics_records_diveNumber(
                            record.diveNumber!,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneCard(
    BuildContext context,
    UnitFormatter units, {
    required String title,
    required IconData icon,
    required Color color,
    required DiveRecord record,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: context.l10n.statistics_records_milestoneSemanticLabel(
          title,
          record.siteName ?? context.l10n.statistics_records_unknownSite,
        ),
        child: InkWell(
          onTap: () => context.push('/dives/${record.diveId}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        record.siteName ??
                            context.l10n.statistics_records_unknownSite,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        units.formatDate(record.dateTime),
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (record.diveNumber != null)
                        Text(
                          context.l10n.statistics_records_diveNumber(
                            record.diveNumber!,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
