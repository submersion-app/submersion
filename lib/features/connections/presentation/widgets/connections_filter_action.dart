import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App bar action opening the shared filter sheet bound to the connections
/// filter, badged while a filter is set. Mirrors StatisticsFilterAction.
class ConnectionsFilterAction extends ConsumerWidget {
  const ConnectionsFilterAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const ValueKey('connections-filter-action'),
      icon: Badge(
        isLabelVisible: ref.watch(connectionsFilterProvider).hasActiveFilters,
        child: const Icon(Icons.filter_list),
      ),
      tooltip: context.l10n.connections_tooltip_filter,
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DiveFilterSheet(
          ref: ref,
          filterProvider: connectionsFilterProvider,
        ),
      ),
    );
  }
}
