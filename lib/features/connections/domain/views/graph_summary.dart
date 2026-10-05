import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

/// What the map in view counts, for the panel's Summary block. The standout
/// facts (most connected, strongest pair, closest) live in `GraphInsights`.
class GraphSummary {
  const GraphSummary._({
    required this.countsByKind,
    required this.connectionCount,
    required this.entitiesAround,
  });

  factory GraphSummary.of(ConnectionGraph graph, {NodeRef? focus}) {
    final others = graph.nodes.where((n) => n.ref != focus).toList();
    final counts = <ConnectionKind, int>{};
    for (final n in others) {
      counts[n.ref.kind] = (counts[n.ref.kind] ?? 0) + 1;
    }
    return GraphSummary._(
      countsByKind: Map.unmodifiable(counts),
      connectionCount: graph.edges.length,
      entitiesAround: others.length,
    );
  }

  /// Orders edges strongest first: more dives, then the more recent last
  /// dive, then by wire ids so ties are stable. Every ranking of edges uses
  /// it, so the panel's lists agree with the insight strip.
  static int strongestFirst(ConnectionEdge a, ConnectionEdge b) {
    if (a.weight != b.weight) return b.weight.compareTo(a.weight);
    if (a.lastDiveAt != b.lastDiveAt) {
      return b.lastDiveAt.compareTo(a.lastDiveAt);
    }
    final bySource = a.source.wire.compareTo(b.source.wire);
    return bySource != 0 ? bySource : a.target.wire.compareTo(b.target.wire);
  }

  final Map<ConnectionKind, int> countsByKind;
  final int connectionCount;
  final int entitiesAround;
}
