import 'package:submersion/features/connections/data/connections_budget.dart';
import 'package:submersion/features/connections/data/connections_node_sql.dart';
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// Everything within [hops] shared-dive steps of a focus, limited to the
/// enabled kinds (the focus's own kind is always present).
///
/// Discovery is breadth-first: each hop reads the neighbours of the previous
/// hop's frontier one kind at a time, excluding what is already placed. It
/// stops once the hops so far hold [nodeBudget] entities: the budget ranks by
/// hop first, so nothing further out could be kept. That is also why a hop
/// can be read as only the top of each kind, as the map loader reads a whole
/// kind: the budget keeps at most twice its size, anything in that top is in
/// the top of its own kind, and only the last hop can be cut. So a hub costs
/// what the budget shows rather than what it touches, and a count carries
/// the rest for the hidden totals. Every frontier has fit the budget.
///
/// Edges are then one pass over every pair of kinds among the placed
/// entities, so lines between neighbours are drawn as well as the spokes.
class AroundLoader {
  const AroundLoader(this._reader);

  final ConnectionsReader _reader;

  Future<ConnectionGraph> load({
    required NodeRef focus,
    required Set<ConnectionKind> kinds,
    required int hops,
    required String? diverId,
    required DiveFilterState filter,
    required int nodeBudget,
  }) async {
    final enabled = kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
    final cap = budgetReach(nodeBudget);
    final placed = <ConnectionKind, Set<String>>{
      focus.kind: {focus.id},
    };
    final totals = <ConnectionKind, int>{focus.kind: 1};
    var frontier = <ConnectionKind, Set<String>>{
      focus.kind: {focus.id},
    };
    final focusRows = await _reader.nodes(
      focus.kind,
      diverId: diverId,
      filter: filter,
      onlyIds: {focus.id},
    );
    final focusNode =
        (focusRows.isEmpty
                ? await _reader.labelOnly(focus, diverId: diverId)
                : focusRows.single)
            .copyWith(hop: 0);
    final reached = <ConnectionNode>[];

    bool budgetFull() =>
        nodeBudget > 0 && totals.values.fold(0, (a, b) => a + b) >= nodeBudget;

    for (
      var hop = 1;
      hop <= hops && frontier.isNotEmpty && !budgetFull();
      hop++
    ) {
      final next = <ConnectionKind, Set<String>>{};
      for (final kind in enabled) {
        final neighbours = NeighboursOf(
          frontier,
          exclude: placed[kind] ?? const {},
        );
        final rows = await _reader.nodes(
          kind,
          diverId: diverId,
          filter: filter,
          limit: cap,
          byRank: true,
          neighboursOf: neighbours,
        );
        if (rows.isEmpty) continue;
        final total = cap != null && rows.length >= cap
            ? await _reader.nodeCount(
                kind,
                diverId: diverId,
                filter: filter,
                neighboursOf: neighbours,
              )
            : rows.length;
        totals[kind] = (totals[kind] ?? 0) + total;
        reached.addAll(rows.map((n) => n.copyWith(hop: hop)));
        next[kind] = {for (final n in rows) n.ref.id};
        placed.putIfAbsent(kind, () => {}).addAll(next[kind]!);
      }
      frontier = next;
    }

    // A focus with no dive in scope has no place among the counts: it leads.
    final ranked = [if (focusRows.isNotEmpty) focusNode, ...reached]
      ..sort(_byKindThenBusiest);
    final nodes = [if (focusRows.isEmpty) focusNode, ...ranked];

    // Cut to the budget before the chord pass (see nodesWithinBudget), so
    // chord work is bounded by the budget, not by the size of the log.
    final kept = nodesWithinBudget(nodes, nodeBudget);
    final keptIds = idsByKind(kept);
    final keptKinds = keptIds.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final edges = <ConnectionEdge>[];
    for (var i = 0; i < keptKinds.length; i++) {
      for (var j = i; j < keptKinds.length; j++) {
        edges.addAll(
          await _reader.edgesWithin(
            keptKinds[i],
            keptKinds[j],
            keptIds,
            diverId: diverId,
            filter: filter,
          ),
        );
      }
    }
    final graph = ConnectionGraph(
      nodes: kept,
      edges: edges,
    ).trimmed(nodeBudget, keep: focus);
    return withDroppedCounts(graph, totals, kept);
  }

  /// The order a graph lists its nodes in, whichever hop reached them: by
  /// kind, then as the node query sorts them.
  static int _byKindThenBusiest(ConnectionNode a, ConnectionNode b) {
    final byKind = a.ref.kind.index.compareTo(b.ref.kind.index);
    if (byKind != 0) return byKind;
    final byDives = b.diveCount.compareTo(a.diveCount);
    if (byDives != 0) return byDives;
    final byLabel = a.label.compareTo(b.label);
    return byLabel != 0 ? byLabel : a.ref.id.compareTo(b.ref.id);
  }
}
