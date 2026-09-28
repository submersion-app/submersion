import 'package:submersion/features/connections/data/connections_budget.dart';
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// A whole map: every entity of each chosen kind, and one edge query per
/// chosen link. Entities without a surviving line stay, as islands.
///
/// Each kind is read only as far as the budget could reach: the budget keeps
/// at most twice its size, and anything in the overall top of that is also
/// in the top of its own kind, read in the budget's order. The rest is only
/// counted, for the hidden totals.
class MapLoader {
  const MapLoader(this._reader);

  final ConnectionsReader _reader;

  Future<ConnectionGraph> load(
    MapSpec spec, {
    required String? diverId,
    required DiveFilterState filter,
    required int nodeBudget,
  }) async {
    final kinds = spec.kinds.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final cap = nodeBudget > 0 ? nodeBudget * 2 : null;
    final nodes = <ConnectionNode>[];
    final totals = <ConnectionKind, int>{};
    for (final k in kinds) {
      final rows = await _reader.nodes(
        k,
        diverId: diverId,
        filter: filter,
        limit: cap,
        byRank: true,
      );
      nodes.addAll(rows);
      totals[k] = cap != null && rows.length >= cap
          ? await _reader.nodeCount(k, diverId: diverId, filter: filter)
          : rows.length;
    }
    // Cut to the budget before the edge queries (see nodesWithinBudget), so
    // a map of every kind and link costs what the budget shows, not the log.
    final kept = nodesWithinBudget(nodes, nodeBudget);
    final keptIds = idsByKind(kept);
    final links = spec.links.toList()..sort((a, b) => a.wire.compareTo(b.wire));
    final edges = <ConnectionEdge>[
      for (final l in links)
        if (keptIds[l.a] != null && keptIds[l.b] != null)
          ...await _reader.edges(
            l.a,
            l.b,
            diverId: diverId,
            filter: filter,
            restrictA: keptIds[l.a],
            restrictB: keptIds[l.b],
            minShared: spec.minSharedDives,
          ),
    ];
    final graph = ConnectionGraph(
      nodes: kept,
      edges: edges,
    ).trimmed(nodeBudget);
    return withDroppedCounts(graph, totals, kept);
  }
}
