import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/year_range_slider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_filter_chips.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Years, the active filter axes as removable chips, the full filter sheet
/// and Clear. Everything here writes `connectionsFilterProvider`.
class FilterTab extends ConsumerWidget {
  const FilterTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chips = activeDiveFilterChips(
      context,
      ref,
      connectionsFilterProvider,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const YearRangeSlider(),
        const SizedBox(height: 8),
        if (chips.isEmpty)
          Text(
            l10n.connections_filter_none,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Wrap(runSpacing: 4, children: chips),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.tune),
              label: Text(l10n.connections_filter_allFilters),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => DiveFilterSheet(
                  ref: ref,
                  filterProvider: connectionsFilterProvider,
                ),
              ),
            ),
            if (chips.isNotEmpty)
              TextButton(
                onPressed: () =>
                    ref.read(connectionsFilterProvider.notifier).state =
                        const DiveFilterState(),
                child: Text(l10n.connections_filter_clear),
              ),
          ],
        ),
      ],
    );
  }
}
