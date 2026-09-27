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
