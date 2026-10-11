import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/graph_insights.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_canvas.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/connections/presentation/widgets/hidden_nodes_chip.dart';
import 'package:submersion/features/connections/presentation/widgets/insight_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The graph view: the canvas with its overlays (insight strip, legend,
/// hidden-node chip, reload error, timeline bar, loading bar).
class ConnectionsGraphStack extends StatelessWidget {
  const ConnectionsGraphStack({
    super.key,
    required this.graph,
    required this.canvasGraph,
    required this.controller,
    required this.colors,
    required this.selection,
    required this.animate,
    required this.bottomInset,
    required this.stripHeight,
    required this.belowStrip,
    required this.highlight,
    required this.groups,
    required this.insights,
    required this.wide,
    required this.display,
    required this.onSelect,
    required this.onFocus,
    required this.onGroups,
    required this.onShowAll,
    required this.reloadFailed,
    required this.onRetry,
    required this.timelineBar,
    required this.loading,
  });

  /// The whole map: the strip, legend and chip describe it.
  final ConnectionGraph graph;

  /// What the canvas draws: [graph], less unconnected nodes when hidden.
  final ConnectionGraph canvasGraph;
  final ConnectionsLayoutController controller;
  final ConnectionKindColors colors;
  final GraphSelection? selection;
  final bool animate;
  final double bottomInset;
  final double stripHeight;
  final double belowStrip;
  final HighlightMode highlight;
  final GraphGroups groups;
  final List<InsightTile> insights;
  final bool wide;
  final ConnectionsDisplay display;
  final ValueChanged<GraphSelection?> onSelect;
  final ValueChanged<NodeRef> onFocus;
  final VoidCallback onGroups;
  final VoidCallback? onShowAll;
  final bool reloadFailed;
  final VoidCallback onRetry;
  final Widget timelineBar;
  final bool loading;

  /// [selection], unless it names a node the canvas does not draw (one
  /// hidden as unconnected); the canvas would dim everything around it.
  GraphSelection? get _drawnSelection => switch (selection) {
    NodeSelection(:final ref) when canvasGraph.nodeFor(ref) == null => null,
    final s => s,
  };

  /// The canvas's accessible summary: counts, then the selection by name.
  String _semanticsLabel(BuildContext context) {
    final l10n = context.l10n;
    final summary = l10n.connections_semantics_summary(
      graph.nodes.length,
      graph.edges.length,
    );
    final String? selected = switch (selection) {
      null => null,
      NodeSelection(:final ref) => graph.nodeFor(ref)?.label,
      EdgeSelection(:final a, :final b) =>
        '${graph.nodeFor(a)?.label ?? a.id}, ${graph.nodeFor(b)?.label ?? b.id}',
    };
    if (selected == null) return summary;
    return '$summary. ${l10n.connections_semantics_selected(selected)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kinds = graph.nodes.map((n) => n.ref.kind).toSet();
    return Stack(
      children: [
        Positioned.fill(
          child: ConnectionsCanvas(
            graph: canvasGraph,
            controller: controller,
            colors: colors,
            selection: _drawnSelection,
            semanticsLabel: _semanticsLabel(context),
            animate: animate,
            bottomInset: bottomInset,
            topInset: stripHeight,
            highlight: highlight,
            groupOf: groups.groupOf,
            labels: display.labels,
            nodeSize: display.nodeSize,
            edges: display.edges,
            kindNames: kindNames(l10n),
            layoutToken: (controller.layout, display.spacing),
            onSelect: onSelect,
            onFocus: onFocus,
          ),
        ),
        Positioned(
          key: const ValueKey('connections-insights'),
          left: 0,
          right: 0,
          top: 8,
          child: InsightStrip(
            graph: graph,
            tiles: insights,
            onSelect: onSelect,
            onGroups: onGroups,
          ),
        ),
        if (!wide)
          Positioned(
            left: 12,
            top: belowStrip,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ConnectionsLegend(
                  kinds: kinds,
                  colors: colors,
                  showTitle: false,
                  highlight: highlight,
                  groupCount: groups.count,
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          top: belowStrip,
          child: HiddenNodesChip(
            count: graph.hiddenNodeCount,
            onShowAll: onShowAll,
          ),
        ),
        if (reloadFailed)
          Positioned(
            left: 12,
            right: 12,
            top: belowStrip + 44,
            child: Card(
              key: const ValueKey('connections-reload-error'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.connections_error_load)),
                    TextButton(
                      onPressed: onRetry,
                      child: Text(l10n.common_action_retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        timelineBar,
        if (loading)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Semantics(
              label: l10n.connections_loading,
              child: const LinearProgressIndicator(
                key: ValueKey('connections-reload-progress'),
                minHeight: 2,
              ),
            ),
          ),
      ],
    );
  }
}
