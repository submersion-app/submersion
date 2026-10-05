import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

/// The communities in a graph: each node in a group of two or more mapped to
/// its group number, numbered largest group first.
class GraphGroups {
  const GraphGroups({required this.groupOf, required this.count});

  static const empty = GraphGroups(groupOf: {}, count: 0);

  final Map<NodeRef, int> groupOf;
  final int count;
}

/// Deterministic asynchronous label propagation.
///
/// Each node starts with its own wire id as its label. Each round visits the
/// nodes in wire order and gives each the label with the largest summed edge
/// weight among its neighbours, ties to the smallest label. Updating in
/// place (asynchronously) converges on two-kind graphs such as buddies and
/// sites, where the synchronous form oscillates between the two sides.
abstract final class LabelPropagation {
  static GraphGroups communities(ConnectionGraph graph, {int maxRounds = 20}) {
    final order = [for (final n in graph.nodes) n.ref]
      ..sort((a, b) => a.wire.compareTo(b.wire));
    final label = {for (final r in order) r: r.wire};
    final neighbours = <NodeRef, List<(NodeRef, int)>>{};
    for (final e in graph.edges) {
      if (e.source == e.target ||
          !label.containsKey(e.source) ||
          !label.containsKey(e.target)) {
        continue;
      }
      (neighbours[e.source] ??= []).add((e.target, e.weight));
      (neighbours[e.target] ??= []).add((e.source, e.weight));
    }
    for (var round = 0; round < maxRounds; round++) {
      var changed = false;
      for (final r in order) {
        final around = neighbours[r];
        if (around == null) continue;
        final score = <String, int>{};
        for (final (n, w) in around) {
          final l = label[n]!;
          score[l] = (score[l] ?? 0) + w;
        }
        String? best;
        var bestScore = -1;
        for (final MapEntry(:key, :value) in score.entries) {
          if (value > bestScore ||
              (value == bestScore && key.compareTo(best!) < 0)) {
            best = key;
            bestScore = value;
          }
        }
        if (best != null && best != label[r]) {
          label[r] = best;
          changed = true;
        }
      }
      if (!changed) break;
    }
    // Members stay in wire order, so each group's first is its smallest.
    final members = <String, List<NodeRef>>{};
    for (final r in order) {
      (members[label[r]!] ??= []).add(r);
    }
    final groups = members.values.where((m) => m.length >= 2).toList()
      ..sort((a, b) {
        final bySize = b.length.compareTo(a.length);
        return bySize != 0 ? bySize : a.first.wire.compareTo(b.first.wire);
      });
    return GraphGroups(
      groupOf: Map.unmodifiable({
        for (var i = 0; i < groups.length; i++)
          for (final r in groups[i]) r: i,
      }),
      count: groups.length,
    );
  }
}
