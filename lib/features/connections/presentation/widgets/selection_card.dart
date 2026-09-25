import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'selection_details.dart';

/// Compact-width selection surface: a bottom-anchored card capped at 40% of
/// the height, scrolling inside. Not a DraggableScrollableSheet, which a
/// mouse cannot resize.
class SelectionCard extends StatelessWidget {
  const SelectionCard({
    super.key,
    required this.graph,
    required this.selection,
    required this.onClose,
  });

  final ConnectionGraph graph;
  final GraphSelection selection;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.4;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Card(
        key: const ValueKey('connections-selection-card'),
        margin: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.common_action_close,
                    onPressed: onClose,
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: GraphSelectionDetails(
                      graph: graph,
                      selection: selection,
                    ),
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
