import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';

/// The nodes a load keeps before it queries edges, so edge work is bounded
/// by [budget] rather than by the size of the log.
///
/// Ranks like `ConnectionGraph.trimmed` (hop, then dive count) and keeps the
/// nodes tied with the last one, since only among those does the final
/// trim's degree tie-break still choose. Ties are capped at twice the
/// budget: most entities two or three hops out share a dive count of one,
/// and an uncapped tie class would bring the whole log back. Beyond the cap
/// ties fall in wire order, so a load is deterministic.
List<ConnectionNode> nodesWithinBudget(List<ConnectionNode> nodes, int budget) {
  if (budget <= 0 || nodes.length <= budget) return nodes;
  int rank(ConnectionNode a, ConnectionNode b) {
    final byHop = (a.hop ?? 0).compareTo(b.hop ?? 0);
    return byHop != 0 ? byHop : b.diveCount.compareTo(a.diveCount);
  }

  final ranked = [...nodes]
    ..sort((a, b) {
      final r = rank(a, b);
      return r != 0 ? r : a.ref.wire.compareTo(b.ref.wire);
    });
  final cap = budget * 2;
  var end = budget;
  while (end < ranked.length &&
      end < cap &&
      rank(ranked[end], ranked[budget - 1]) == 0) {
    end++;
  }
  return ranked.sublist(0, end);
}

/// The ids of [nodes], grouped by kind.
Map<ConnectionKind, Set<String>> idsByKind(Iterable<ConnectionNode> nodes) {
  final out = <ConnectionKind, Set<String>>{};
  for (final n in nodes) {
    out.putIfAbsent(n.ref.kind, () => {}).add(n.ref.id);
  }
  return out;
}

/// [graph] with the nodes of [all] that the budget cut before the edge
/// queries (those not in [kept]) added to its hidden counts.
ConnectionGraph withDropped(
  ConnectionGraph graph,
  List<ConnectionNode> all,
  List<ConnectionNode> kept,
) {
  final totals = <ConnectionKind, int>{};
  for (final n in all) {
    totals[n.ref.kind] = (totals[n.ref.kind] ?? 0) + 1;
  }
  return withDroppedCounts(graph, totals, kept);
}

/// [withDropped] for a load that read only the top of each kind: [totals]
/// holds each kind's full entity count, and whatever [kept] does not hold
/// is added to the hidden counts.
ConnectionGraph withDroppedCounts(
  ConnectionGraph graph,
  Map<ConnectionKind, int> totals,
  List<ConnectionNode> kept,
) {
  final keptByKind = <ConnectionKind, int>{};
  for (final n in kept) {
    keptByKind[n.ref.kind] = (keptByKind[n.ref.kind] ?? 0) + 1;
  }
  final hiddenByKind = {...graph.hiddenByKind};
  var dropped = 0;
  for (final MapEntry(key: kind, value: total) in totals.entries) {
    final cut = total - (keptByKind[kind] ?? 0);
    if (cut <= 0) continue;
    hiddenByKind[kind] = (hiddenByKind[kind] ?? 0) + cut;
    dropped += cut;
  }
  if (dropped == 0) return graph;
  return graph.copyWith(
    hiddenNodeCount: graph.hiddenNodeCount + dropped,
    hiddenByKind: Map.unmodifiable(hiddenByKind),
  );
}
