import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// AppBar action opening the statistics filter, badged while a filter is set.
///
/// Extracted from the three places that had hand-rolled the same block. The
/// statistics detail pages had no filter affordance at all, so on a phone the
/// span governing a chart could only be changed from the tab root and then
/// drilled back into (issue #299).
class StatisticsFilterAction extends ConsumerWidget {
  const StatisticsFilterAction({super.key, this.iconSize});

  /// Overrides the icon size. The compact statistics AppBar draws it at 20.
  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const ValueKey('statistics-filter-action'),
      icon: Badge(
        isLabelVisible: ref.watch(statisticsFilterProvider).hasActiveFilters,
        child: Icon(Icons.filter_list, size: iconSize),
      ),
      tooltip: context.l10n.statistics_tooltip_filter,
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) =>
            DiveFilterSheet(ref: ref, filterProvider: statisticsFilterProvider),
      ),
    );
  }
}
