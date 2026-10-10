import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionEdge _e(String a, String b) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: 3,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

final _nodes = [
  for (final id in ['a1', 'a2', 'a3', 'z1', 'z2', 'z3', 'lone']) _b(id),
];

// One edge (a3-z1) joins the two groups, so connected components alone
// would lay them out as one island.
final _edges = [
  _e('a1', 'a2'),
  _e('a2', 'a3'),
  _e('a1', 'a3'),
  _e('z1', 'z2'),
  _e('z2', 'z3'),
  _e('z1', 'z3'),
  _e('a3', 'z1'),
];

final _islands = [
  [_b('a1'), _b('a2'), _b('a3')],
  [_b('z1'), _b('z2'), _b('z3')],
];

WholeWebLayout _settled() {
  final web = WholeWebLayout(nodes: _nodes, edges: _edges, islands: _islands);
  while (!web.settled) {
    web.advance(50);
  }
  return web;
}

void main() {
  test('given islands are laid out apart even when an edge joins them', () {
    final f = _settled().frame;
    GraphBounds box(List<String> ids) =>
        GraphBounds.of([for (final id in ids) f.positions[_b(id)]!]);
    final a = box(['a1', 'a2', 'a3']);
    final z = box(['z1', 'z2', 'z3']);
    final apart =
        a.right < z.left ||
        z.right < a.left ||
        a.bottom < z.top ||
        z.bottom < a.top;
    expect(apart, isTrue);
  });

  test('a node in no island goes in the grid below', () {
    final f = _settled().frame;
    final lowest = [
      for (final id in ['a1', 'a2', 'a3', 'z1', 'z2', 'z3'])
        f.positions[_b(id)]!.y,
    ].reduce((x, y) => x > y ? x : y);
    expect(f.positions[_b('lone')]!.y, greaterThan(lowest));
  });

  test('islands step over ticks rather than settling at once', () {
    final web = WholeWebLayout(nodes: _nodes, edges: _edges, islands: _islands);
    expect(web.settled, isFalse);
  });

  test('is deterministic', () {
    expect(_settled().frame.positions, _settled().frame.positions);
  });
}
