import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown only while a filter is active: what is in view, and a clear button.
class ConnectionsFilterBar extends ConsumerWidget {
  const ConnectionsFilterBar({super.key, required this.graph});

  final AsyncValue<ConnectionGraph> graph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(connectionsFilterProvider);
    if (!filter.hasActiveFilters) return const SizedBox.shrink();
    final l10n = context.l10n;
    final g = graph.value;
    final summary = g == null
        ? ''
        : '${l10n.connections_filterBar_nodes(g.nodes.length)}, '
              '${l10n.connections_filterBar_edges(g.edges.length)}';
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('connections-filter-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(summary, style: theme.textTheme.bodyMedium)),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.connections_filterBar_clear,
            onPressed: () =>
                ref.read(connectionsFilterProvider.notifier).state =
                    const DiveFilterState(),
          ),
        ],
      ),
    );
  }
}
