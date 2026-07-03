import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Summary bar shown at the top of the Statistics tab when a filter is active.
/// Shows the matching dive count and a clear affordance so a scoped total is
/// never mysterious.
class StatisticsFilterBar extends ConsumerWidget {
  const StatisticsFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(statisticsFilterProvider);
    if (!filter.hasActiveFilters) return const SizedBox.shrink();

    final statsAsync = ref.watch(filteredDiveStatisticsProvider);
    final countText = statsAsync.maybeWhen(
      data: (s) => context.l10n.statistics_filterBar_diveCount(s.totalDives),
      orElse: () => '',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              countText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: context.l10n.statistics_filterBar_clear,
            onPressed: () => ref.read(statisticsFilterProvider.notifier).state =
                const DiveFilterState(),
          ),
        ],
      ),
    );
  }
}
