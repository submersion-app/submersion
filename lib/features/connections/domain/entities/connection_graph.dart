import 'package:equatable/equatable.dart';

import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

class ConnectionGraph extends Equatable {
  const ConnectionGraph({
    required this.nodes,
    required this.edges,
    this.hiddenNodeCount = 0,
  });

  static const empty = ConnectionGraph(nodes: [], edges: []);

  final List<ConnectionNode> nodes;
  final List<ConnectionEdge> edges;

  /// Nodes removed by [trimmed]; shown as "N more not shown".
  final int hiddenNodeCount;

  bool get isEmpty => nodes.isEmpty;

  int get maxDiveCount =>
      nodes.fold(0, (m, n) => n.diveCount > m ? n.diveCount : m);

  int get maxWeight => edges.fold(0, (m, e) => e.weight > m ? e.weight : m);

  ConnectionNode? nodeFor(NodeRef ref) {
    for (final n in nodes) {
      if (n.ref == ref) return n;
    }
    return null;
  }

  List<ConnectionEdge> edgesOf(NodeRef ref) =>
      edges.where((e) => e.touches(ref)).toList();

  int weightedDegree(NodeRef ref) =>
      edgesOf(ref).fold(0, (sum, e) => sum + e.weight);

  /// Keeps the top [budget] nodes by dive count, then weighted degree, then
  /// id, plus [keep] (the focus) if it would otherwise fall out. Edges that
  /// touch a removed node are dropped. Returns `this` when nothing is cut.
  ConnectionGraph trimmed(int budget, {NodeRef? keep}) {
    if (nodes.length <= budget) return this;
    final degree = <NodeRef, int>{};
    for (final e in edges) {
      degree[e.source] = (degree[e.source] ?? 0) + e.weight;
      degree[e.target] = (degree[e.target] ?? 0) + e.weight;
    }
    final ranked = [...nodes]
      ..sort((a, b) {
        final byDives = b.diveCount.compareTo(a.diveCount);
        if (byDives != 0) return byDives;
        final byDegree = (degree[b.ref] ?? 0).compareTo(degree[a.ref] ?? 0);
        if (byDegree != 0) return byDegree;
        return a.ref.wire.compareTo(b.ref.wire);
      });
    final kept = ranked.take(budget).toList();
    if (keep != null && !kept.any((n) => n.ref == keep)) {
      final focus = nodeFor(keep);
      if (focus != null) {
        kept.removeLast();
        kept.add(focus);
      }
    }
    final keptRefs = kept.map((n) => n.ref).toSet();
    return ConnectionGraph(
      nodes: kept,
      edges: edges
          .where(
            (e) => keptRefs.contains(e.source) && keptRefs.contains(e.target),
          )
          .toList(),
      hiddenNodeCount: nodes.length - kept.length,
    );
  }

  ConnectionGraph copyWith({
    List<ConnectionNode>? nodes,
    List<ConnectionEdge>? edges,
    int? hiddenNodeCount,
  }) {
    return ConnectionGraph(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      hiddenNodeCount: hiddenNodeCount ?? this.hiddenNodeCount,
    );
  }

  @override
  List<Object?> get props => [nodes, edges, hiddenNodeCount];
}
