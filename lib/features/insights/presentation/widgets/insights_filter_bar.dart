import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/presentation/insights_saved_group.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_group_menu.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The row at the top of Insights: which dives the numbers below cover, how
/// many that is, and a way to change it, so a scoped total is never
/// mysterious. Tinted while it narrows them, so a scoped page reads as one
/// at a glance.
class InsightsFilterBar extends ConsumerWidget {
  const InsightsFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(insightsFilterProvider);
    final loads =
        ref.watch(savedQueryLoadsProvider(QuerySubject.dives.name)).value ??
        const <SavedQueryLoad>[];
    final statsAsync = ref.watch(filteredDiveStatisticsProvider);
    final countText = statsAsync.maybeWhen(
      data: (s) => context.l10n.insights_filterBar_diveCount(s.totalDives),
      orElse: () => '',
    );
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: filter.hasActiveFilters
          ? theme.colorScheme.surfaceContainerHighest
          : null,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: InsightsGroupMenu(
                filter: filter,
                active: activeSavedGroup(filter, loads),
                loads: loads,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Gives way to the group's name in a narrow pane or at a large
          // text size.
          Flexible(
            child: Padding(
              padding: filter.hasActiveFilters
                  ? EdgeInsets.zero
                  : const EdgeInsetsDirectional.only(end: 8),
              child: Text(
                countText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          if (filter.hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: context.l10n.insights_filterBar_clear,
              onPressed: () => ref.read(insightsFilterProvider.notifier).state =
                  const DiveFilterState(),
            ),
        ],
      ),
    );
  }
}
