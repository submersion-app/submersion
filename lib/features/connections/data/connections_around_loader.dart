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
/// Discovery is breadth-first: each hop joins the previous hop's frontier to
/// every enabled kind, excluding what is already placed. Edges are then one
/// pass over every pair of kinds among the placed entities, so lines between
/// neighbours are drawn as well as the spokes.
class AroundLoader {
  const AroundLoader(this._reader);

  final ConnectionsReader _reader;

  Future<ConnectionGraph> load({
    required NodeRef focus,
    required Set<ConnectionKind> kinds,
    required int hops,
    required String? diverId,
    required DiveFilterState filter,
  }) async {
    final enabled = kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
    final placed = <ConnectionKind, Set<String>>{
      focus.kind: {focus.id},
    };
    final hopOf = <NodeRef, int>{focus: 0};
    var frontier = <ConnectionKind, Set<String>>{
      focus.kind: {focus.id},
    };

    for (var hop = 1; hop <= hops && frontier.isNotEmpty; hop++) {
      final next = <ConnectionKind, Set<String>>{};
      for (final entry in frontier.entries) {
        for (final kind in enabled) {
          final found = await _reader.edges(
            entry.key,
            kind,
            diverId: diverId,
            filter: filter,
            restrictA: entry.value,
            excludeB: placed[kind] ?? const <String>{},
          );
          for (final e in found) {
            if (hopOf.containsKey(e.target)) continue;
            hopOf[e.target] = hop;
            placed.putIfAbsent(kind, () => {}).add(e.target.id);
            next.putIfAbsent(kind, () => {}).add(e.target.id);
          }
        }
      }
      frontier = next;
    }

    final nodes = <ConnectionNode>[];
    final placedKinds = placed.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final kind in placedKinds) {
      final rows = await _reader.nodes(
        kind,
        diverId: diverId,
        filter: filter,
        onlyIds: placed[kind],
      );
      nodes.addAll(rows.map((n) => n.copyWith(hop: hopOf[n.ref])));
    }
    if (!nodes.any((n) => n.ref == focus)) {
      nodes.insert(0, (await _reader.labelOnly(focus)).copyWith(hop: 0));
    }

    final edges = <ConnectionEdge>[];
    for (var i = 0; i < placedKinds.length; i++) {
      for (var j = i; j < placedKinds.length; j++) {
        edges.addAll(
          await _reader.edges(
            placedKinds[i],
            placedKinds[j],
            diverId: diverId,
            filter: filter,
            restrictA: placed[placedKinds[i]],
            restrictB: placed[placedKinds[j]],
          ),
        );
      }
    }
    return ConnectionGraph(nodes: nodes, edges: edges);
  }
}
