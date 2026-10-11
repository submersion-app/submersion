import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/presentation/widgets/hidden_nodes_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The line above a table or the matrix: how much is on the map, and how
/// much the node budget left out, with Show all.
class TableHeaderBar extends StatelessWidget {
  const TableHeaderBar({
    super.key,
    required this.graph,
    required this.onShowAll,
  });

  final ConnectionGraph graph;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${l10n.connections_summary_entitiesAround(graph.nodes.length)}'
              ' • ${l10n.connections_filterBar_edges(graph.edges.length)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (graph.hiddenNodeCount > 0)
            HiddenNodesChip(count: graph.hiddenNodeCount, onShowAll: onShowAll),
        ],
      ),
    );
  }
}
