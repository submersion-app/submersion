import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/connections_matrix.dart';
import 'package:submersion/features/connections/presentation/views/entities_table.dart';
import 'package:submersion/features/connections/presentation/views/pairs_table.dart';
import 'package:submersion/features/connections/presentation/views/table_header_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Pairs, Entities and Matrix views: a count line, the chosen view, the
/// year play pill and the loading bar. The graph-only overlays stay away.
class ConnectionsTableArea extends StatelessWidget {
  const ConnectionsTableArea({
    super.key,
    required this.view,
    required this.graph,
    required this.colors,
    required this.selection,
    required this.onSelect,
    required this.onShowAll,
    required this.bottomInset,
    required this.playPill,
    required this.loading,
  });

  final ConnectionsViewKind view;

  /// The whole map, unconnected nodes included.
  final ConnectionGraph graph;
  final ConnectionKindColors colors;
  final GraphSelection? selection;
  final ValueChanged<GraphSelection?> onSelect;
  final VoidCallback? onShowAll;

  /// Screen pixels at the bottom covered by the phone's panel sheet.
  final double bottomInset;
  final Widget playPill;
  final bool loading;

  Widget _body() => switch (view) {
    ConnectionsViewKind.pairs => PairsTable(
      key: const ValueKey('connections-view-pairs'),
      graph: graph,
      colors: colors,
      selection: selection,
      onSelect: onSelect,
    ),
    ConnectionsViewKind.entities => EntitiesTable(
      key: const ValueKey('connections-view-entities'),
      graph: graph,
      colors: colors,
      selection: selection,
      onSelect: onSelect,
    ),
    ConnectionsViewKind.matrix => ConnectionsMatrix(
      key: const ValueKey('connections-view-matrix'),
      graph: graph,
      colors: colors,
      selection: selection,
      onSelect: onSelect,
    ),
    ConnectionsViewKind.graph => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TableHeaderBar(graph: graph, onShowAll: onShowAll),
                const Divider(height: 1),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
        playPill,
        if (loading)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Semantics(
              label: context.l10n.connections_loading,
              child: const LinearProgressIndicator(minHeight: 2),
            ),
          ),
      ],
    );
  }
}
