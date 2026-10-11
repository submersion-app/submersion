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

  test('entities sort by name, kind and strongest connection', () {
    List<String> by(EntitiesColumn c, {bool asc = true}) => [
      for (final r in ConnectionsTableRows.entities(_graph, c, ascending: asc))
        r.node.label,
    ];
    expect(by(EntitiesColumn.name), ['Ann', 'Bob', 'Reef', 'Wall']);
    expect(by(EntitiesColumn.kind), ['Ann', 'Bob', 'Reef', 'Wall']);
    expect(by(EntitiesColumn.strongest), ['Reef', 'Wall', 'Ann', 'Bob']);
  });

  test('entities sort by first dive, a missing date as the oldest', () {
    final dated = _graph.copyWith(
      nodes: [
        for (final n in _graph.nodes)
          n.ref.id == 'ann'
              ? n.copyWith(firstDiveAt: DateTime.utc(2021))
              : n.ref.id == 'reef'
              ? n.copyWith(firstDiveAt: DateTime.utc(2019))
              : n,
      ],
    );
    final rows = ConnectionsTableRows.entities(
      dated,
      EntitiesColumn.first,
      ascending: true,
    );
    expect(rows.map((r) => r.node.label), ['Bob', 'Wall', 'Reef', 'Ann']);
  });

  test('pairs sort by first shared dive and by the first end', () {
    final byA = ConnectionsTableRows.pairs(
      _graph,
      PairsColumn.a,
      ascending: true,
    );
    expect(byA.map((e) => e.source.id), ['ann', 'ann', 'bob']);
    final byFirst = ConnectionsTableRows.pairs(
      _graph,
      PairsColumn.first,
      ascending: false,
    );
    expect(byFirst, hasLength(3));
  });

  test('names sort alphabetically, ignoring case and accents', () {
    final graph = ConnectionGraph(
      nodes: [
        ConnectionNode(ref: _b('bob'), label: 'Bob', diveCount: 1),
        ConnectionNode(ref: _b('emile'), label: 'Émile', diveCount: 1),
        ConnectionNode(ref: _b('alice'), label: 'alice', diveCount: 1),
        ConnectionNode(ref: _s('reef'), label: 'Reef', diveCount: 3),
      ],
      edges: [
        _e(_b('bob'), _s('reef'), 1, 2020),
        _e(_b('emile'), _s('reef'), 1, 2020),
        _e(_b('alice'), _s('reef'), 1, 2020),
      ],
    );
    final names = ConnectionsTableRows.entities(
      graph,
      EntitiesColumn.name,
      ascending: true,
    ).map((r) => r.node.label);
    expect(names, ['alice', 'Bob', 'Émile', 'Reef']);
    final pairs = ConnectionsTableRows.pairs(
      graph,
      PairsColumn.a,
      ascending: true,
    ).map((e) => e.source.id);
    expect(pairs, ['alice', 'bob', 'emile']);
  });
}
