import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/views/table_rows.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);

ConnectionEdge _e(NodeRef a, NodeRef b, int w, int lastYear) => ConnectionEdge(
  source: a,
  target: b,
  weight: w,
  firstDiveAt: DateTime.utc(2019),
  lastDiveAt: DateTime.utc(lastYear),
);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('ann'), label: 'Ann', diveCount: 9),
    ConnectionNode(ref: _b('bob'), label: 'Bob', diveCount: 4),
    ConnectionNode(ref: _s('reef'), label: 'Reef', diveCount: 6),
    ConnectionNode(ref: _s('wall'), label: 'Wall', diveCount: 1),
  ],
  edges: [
    _e(_b('ann'), _s('reef'), 5, 2023),
    _e(_b('bob'), _s('reef'), 2, 2024),
    _e(_b('ann'), _s('wall'), 1, 2020),
  ],
);

void main() {
  test('pairs sort by shared dives, or by last shared dive ascending', () {
    final rows = ConnectionsTableRows.pairs(
      _graph,
      PairsColumn.shared,
      ascending: false,
    );
    expect(rows.map((e) => e.weight), [5, 2, 1]);
    final up = ConnectionsTableRows.pairs(
      _graph,
      PairsColumn.last,
      ascending: true,
    );
    expect(up.map((e) => e.lastDiveAt.year), [2020, 2023, 2024]);
  });

  test('pairs sort by label, ties by the other end', () {
    final rows = ConnectionsTableRows.pairs(
      _graph,
      PairsColumn.b,
      ascending: true,
    );
    expect(rows.map((e) => '${e.source.id}-${e.target.id}'), [
      'ann-reef',
      'bob-reef',
      'ann-wall',
    ]);
  });

  test('entity rows count connections and find the strongest', () {
    final rows = ConnectionsTableRows.entities(
      _graph,
      EntitiesColumn.dives,
      ascending: false,
    );
    expect(rows.map((r) => r.node.label), ['Ann', 'Reef', 'Bob', 'Wall']);
    final ann = rows.first;
    expect(ann.links, 2);
    expect(ann.strongest?.label, 'Reef');
    expect(ann.strongestWeight, 5);
  });

  test('entities sort by connections then by name', () {
    final rows = ConnectionsTableRows.entities(
      _graph,
      EntitiesColumn.links,
      ascending: false,
    );
    expect(rows.map((r) => r.node.label), ['Ann', 'Reef', 'Bob', 'Wall']);
  });

  test('text columns start ascending, numbers and dates descending', () {
    expect(ConnectionsTableRows.startsAscending(PairsColumn.a), isTrue);
    expect(ConnectionsTableRows.startsAscending(EntitiesColumn.name), isTrue);
    expect(ConnectionsTableRows.startsAscending(PairsColumn.shared), isFalse);
    expect(ConnectionsTableRows.startsAscending(EntitiesColumn.first), isFalse);
  });
}
