import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/views/graph_summary.dart';

enum InsightKind {
  mostConnected,
  strongestPair,
  closest,
  newest,
  driftingApart,
  groups,
}

/// One standout fact about the map in view. [node] is the entity a tile
/// names (in Around mode, the far end of a centre edge); [edge] is the pair
/// behind it; [value] is a weighted degree, an edge weight or a group count.
class InsightTile {
  const InsightTile({required this.kind, this.node, this.edge, this.value = 0});

  final InsightKind kind;
  final ConnectionNode? node;
  final ConnectionEdge? edge;
  final int value;

  /// What tapping the tile selects; null for groups, which switches the
  /// highlight mode instead.
  GraphSelection? get target {
    final e = edge;
    if (e != null) return EdgeSelection(e.source, e.target);
    final n = node;
    return n == null ? null : NodeSelection(n.ref);
  }
}

/// The insight strip's facts for the graph in view. In map mode they cover
/// the whole graph; in Around mode the first three are about the centre.
/// A fact with no evidence is left out, never shown as "none".
abstract final class GraphInsights {
  static List<InsightTile> of(
    ConnectionGraph graph, {
    NodeRef? focus,
    required GraphGroups groups,
  }) {
    if (graph.isEmpty) return const [];
    final most = _mostConnected(graph, focus);
    final groupsTile = groups.count == 0
        ? null
        : InsightTile(kind: InsightKind.groups, value: groups.count);
    if (focus == null) {
      final strongest = _first(graph.edges, GraphSummary.strongestFirst);
      return [
        ?most,
        if (strongest != null)
          InsightTile(
            kind: InsightKind.strongestPair,
            edge: strongest,
            value: strongest.weight,
          ),
        ?_edgeTile(graph, InsightKind.newest, _newest(graph.edges), null),
        ?_edgeTile(
          graph,
          InsightKind.driftingApart,
          _drifting(graph.edges),
          null,
        ),
        ?groupsTile,
      ];
    }
    final mine = graph.edges.where((e) => e.touches(focus)).toList();
    return [
      ?_edgeTile(
        graph,
        InsightKind.closest,
        _first(mine, GraphSummary.strongestFirst),
        focus,
      ),
      ?_edgeTile(graph, InsightKind.newest, _newest(mine), focus),
      ?_edgeTile(graph, InsightKind.driftingApart, _drifting(mine), focus),
      ?most,
      ?groupsTile,
    ];
  }

  /// Highest weighted degree, then more dives, then the label; never the
  /// focus, and left out when nothing is connected.
  static InsightTile? _mostConnected(ConnectionGraph graph, NodeRef? focus) {
    final degree = <NodeRef, int>{};
    for (final e in graph.edges) {
      degree[e.source] = (degree[e.source] ?? 0) + e.weight;
      degree[e.target] = (degree[e.target] ?? 0) + e.weight;
    }
    ConnectionNode? best;
    for (final n in graph.nodes) {
      if (n.ref == focus) continue;
      if (best == null) {
        best = n;
        continue;
      }
      final byDegree = (degree[n.ref] ?? 0).compareTo(degree[best.ref] ?? 0);
      if (byDegree > 0 ||
          (byDegree == 0 &&
              (n.diveCount > best.diveCount ||
                  (n.diveCount == best.diveCount &&
                      n.label.compareTo(best.label) < 0)))) {
        best = n;
      }
    }
    final d = degree[best?.ref] ?? 0;
    if (best == null || d == 0) return null;
    return InsightTile(kind: InsightKind.mostConnected, node: best, value: d);
  }

  /// The latest first shared dive; ties by strength.
  static ConnectionEdge? _newest(List<ConnectionEdge> edges) =>
      _first(edges, (a, b) {
        final c = b.firstDiveAt.compareTo(a.firstDiveAt);
        return c != 0 ? c : GraphSummary.strongestFirst(a, b);
      });

  /// Among pairs with two or more dives, the oldest last shared dive; ties
  /// to the heavier pair, then by strength.
  static ConnectionEdge? _drifting(List<ConnectionEdge> edges) =>
      _first(edges.where((e) => e.weight >= 2).toList(), (a, b) {
        final c = a.lastDiveAt.compareTo(b.lastDiveAt);
        if (c != 0) return c;
        final w = b.weight.compareTo(a.weight);
        return w != 0 ? w : GraphSummary.strongestFirst(a, b);
      });

  static ConnectionEdge? _first(
    List<ConnectionEdge> edges,
    int Function(ConnectionEdge, ConnectionEdge) compare,
  ) {
    ConnectionEdge? best;
    for (final e in edges) {
      if (best == null || compare(e, best) < 0) best = e;
    }
    return best;
  }

  static InsightTile? _edgeTile(
    ConnectionGraph graph,
    InsightKind kind,
    ConnectionEdge? edge,
    NodeRef? focus,
  ) {
    if (edge == null) return null;
    final other = focus == null ? null : edge.otherEnd(focus);
    return InsightTile(
      kind: kind,
      edge: edge,
      node: other == null ? null : graph.nodeFor(other),
      value: edge.weight,
    );
  }
}
