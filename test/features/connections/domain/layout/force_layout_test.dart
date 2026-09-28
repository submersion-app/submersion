import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/force_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionEdge _e(String a, String b, [int w = 1]) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: w,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  final nodes = [_b('a'), _b('b'), _b('c'), _b('d')];
  final edges = [_e('a', 'b', 4), _e('b', 'c'), _e('a', 'c')];

  ForceLayout build() => ForceLayout(nodes: nodes, edges: edges);

  test('two runs from the same input give identical positions', () {
    final l1 = build()..advance(300);
    final l2 = build()..advance(300);
    expect(l1.frame.positions, l2.frame.positions);
  });

  test('settles within the iteration bound and stays finite', () {
    final l = build();
    expect(l.settled, isFalse);
    l.advance(300);
    expect(l.settled, isTrue);
    expect(l.iteration, lessThanOrEqualTo(300));
    expect(l.frame.positions.values.every((p) => p.isFinite), isTrue);
    expect(l.frame.positions.length, 4);
  });

  test('connected nodes end closer than an unconnected one', () {
    final l = build()..advance(300);
    final p = l.frame.positions;
    final ab = p[_b('a')]!.distanceTo(p[_b('b')]!);
    final ad = p[_b('a')]!.distanceTo(p[_b('d')]!);
    final bd = p[_b('b')]!.distanceTo(p[_b('d')]!);
    expect(ab, lessThan(ad));
    expect(ab, lessThan(bd));
  });

  test('a heavier edge is shorter than a lighter one', () {
    final l = build()..advance(300);
    final p = l.frame.positions;
    final ab = p[_b('a')]!.distanceTo(p[_b('b')]!);
    final bc = p[_b('b')]!.distanceTo(p[_b('c')]!);
    expect(ab, lessThan(bc));
  });

  test('pinned nodes do not move and clearPins releases them', () {
    final l = build();
    l.pin(_b('a'), const GraphPoint(500, 500));
    l.advance(50);
    expect(l.frame.positions[_b('a')], const GraphPoint(500, 500));
    expect(l.pinned, {_b('a')});
    l.clearPins();
    l.advance(50);
    expect(l.frame.positions[_b('a')], isNot(const GraphPoint(500, 500)));
  });

  test('coincident seeds never produce a non-finite coordinate', () {
    final l = ForceLayout(
      nodes: nodes,
      edges: edges,
      initialPositions: {for (final n in nodes) n: GraphPoint.zero},
    );
    l.advance(300);
    expect(l.frame.positions.values.every((p) => p.isFinite), isTrue);
    expect(l.frame.positions.values.toSet().length, 4);
  });

  test('a warm start keeps known nodes near their previous positions', () {
    final cold = build()..advance(300);
    final warm = ForceLayout(
      nodes: [...nodes, _b('e')],
      edges: [...edges, _e('c', 'e')],
      initialPositions: cold.frame.positions,
    );
    final before = warm.frame.positions[_b('a')]!;
    warm.advance(30);
    expect(warm.frame.positions[_b('a')]!.distanceTo(before), lessThan(60));
    expect(warm.frame.positions.containsKey(_b('e')), isTrue);
  });

  test('empty and single-node graphs are settled immediately', () {
    final empty = ForceLayout(nodes: const [], edges: const []);
    expect(empty.settled, isTrue);
    expect(empty.frame.positions, isEmpty);
    final one = ForceLayout(nodes: [_b('a')], edges: const []);
    expect(one.settled, isTrue);
    expect(one.frame.positions.length, 1);
  });
}
