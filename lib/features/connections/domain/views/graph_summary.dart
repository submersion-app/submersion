import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

/// What the map in view says, for the panel's Summary block.
class GraphSummary {
  const GraphSummary._({
    required this.countsByKind,
    required this.connectionCount,
    required this.mostConnected,
    required this.mostConnectedDegree,
    required this.strongest,
    required this.entitiesAround,
    required this.closest,
    required this.closestWeight,
  });

  factory GraphSummary.of(ConnectionGraph graph, {NodeRef? focus}) {
    final others = graph.nodes.where((n) => n.ref != focus).toList();
    final counts = <ConnectionKind, int>{};
    for (final n in others) {
      counts[n.ref.kind] = (counts[n.ref.kind] ?? 0) + 1;
    }
    final degree = <NodeRef, int>{};
    for (final e in graph.edges) {
      degree[e.source] = (degree[e.source] ?? 0) + e.weight;
      degree[e.target] = (degree[e.target] ?? 0) + e.weight;
    }
    ConnectionNode? most;
    for (final n in others) {
      if (most == null) {
        most = n;
        continue;
      }
      final byDegree = (degree[n.ref] ?? 0).compareTo(degree[most.ref] ?? 0);
      if (byDegree > 0 ||
          (byDegree == 0 &&
              (n.diveCount > most.diveCount ||
                  (n.diveCount == most.diveCount &&
                      n.label.compareTo(most.label) < 0)))) {
        most = n;
      }
    }
    ConnectionEdge? strongest;
    for (final e in graph.edges) {
      if (strongest == null || _stronger(e, strongest)) strongest = e;
    }
    ConnectionEdge? closestEdge;
    if (focus != null) {
      for (final e in graph.edges.where((e) => e.touches(focus))) {
        if (closestEdge == null || _stronger(e, closestEdge)) closestEdge = e;
      }
    }
    final closestRef = closestEdge?.otherEnd(focus!);
    return GraphSummary._(
      countsByKind: Map.unmodifiable(counts),
      connectionCount: graph.edges.length,
      mostConnected: (degree[most?.ref] ?? 0) > 0 ? most : null,
      mostConnectedDegree: degree[most?.ref] ?? 0,
      strongest: strongest,
      entitiesAround: others.length,
      closest: closestRef == null ? null : graph.nodeFor(closestRef),
      closestWeight: closestEdge?.weight ?? 0,
    );
  }

  static bool _stronger(ConnectionEdge a, ConnectionEdge b) {
    if (a.weight != b.weight) return a.weight > b.weight;
    if (a.lastDiveAt != b.lastDiveAt) return a.lastDiveAt.isAfter(b.lastDiveAt);
    return a.source.wire.compareTo(b.source.wire) < 0;
  }

  final Map<ConnectionKind, int> countsByKind;
  final int connectionCount;
  final ConnectionNode? mostConnected;
  final int mostConnectedDegree;
  final ConnectionEdge? strongest;
  final int entitiesAround;
  final ConnectionNode? closest;
  final int closestWeight;
}
