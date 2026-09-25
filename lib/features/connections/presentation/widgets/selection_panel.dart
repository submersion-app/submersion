import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'selection_details.dart';

/// Wide-width side panel: lens, filter, year range and legend above, the
/// selection (or a hint) below.
class SelectionPanel extends StatelessWidget {
  const SelectionPanel({
    super.key,
    required this.graph,
    required this.children,
    this.selection,
  });

  static const double width = 320;

  final ConnectionGraph graph;
  final GraphSelection? selection;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = selection;
    return Container(
      key: const ValueKey('connections-selection-panel'),
      width: width,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...children,
          const Divider(height: 32),
          if (selected != null)
            GraphSelectionDetails(graph: graph, selection: selected)
          else
            Text(
              context.l10n.connections_selection_hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
