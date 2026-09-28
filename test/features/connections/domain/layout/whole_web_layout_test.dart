import 'dart:math' as math;

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
  weight: 1,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  final nodes = [_b('a'), _b('b'), _b('c'), _b('x'), _b('y'), _b('solo')];
  final edges = [_e('a', 'b'), _e('b', 'c'), _e('x', 'y')];

  test('every node is placed and islands stay apart', () {
    final l = WholeWebLayout(nodes: nodes, edges: edges)..advance(400);
    expect(l.settled, isTrue);
    final p = l.frame.positions;
    expect(p.length, 6);
    final abc = [p[_b('a')]!, p[_b('b')]!, p[_b('c')]!];
    final xy = [p[_b('x')]!, p[_b('y')]!];
    for (final u in abc) {
      for (final v in xy) {
        expect(u.distanceTo(v), greaterThan(40));
      }
    }
    expect(p[_b('solo')]!.isFinite, isTrue);
  });

  test('deterministic across runs', () {
    final l1 = WholeWebLayout(nodes: nodes, edges: edges)..advance(400);
    final l2 = WholeWebLayout(nodes: nodes, edges: edges)..advance(400);
    expect(l1.frame.positions, l2.frame.positions);
  });

  test('moveNode pins in world space after settling', () {
    final l = WholeWebLayout(nodes: nodes, edges: edges)..advance(400);
    l.moveNode(_b('a'), const GraphPoint(1000, 1000));
    l.advance(20);
    final a = l.frame.positions[_b('a')]!;
    expect(a.distanceTo(const GraphPoint(1000, 1000)), lessThan(0.001));
    l.clearPins();
    l.advance(50);
    expect(
      l.frame.positions[_b('a')]!.distanceTo(const GraphPoint(1000, 1000)),
      greaterThan(1),
    );
  });

  test('an empty graph is settled and empty', () {
    final l = WholeWebLayout(nodes: const [], edges: const []);
    expect(l.settled, isTrue);
    expect(l.frame.positions, isEmpty);
  });

  test('single nodes sit in a grid below the linked components, in order', () {
    final l = WholeWebLayout(
      nodes: [_b('solo2'), _b('a'), _b('b'), _b('solo1')],
      edges: [_e('a', 'b')],
    )..advance(400);
    final p = l.frame.positions;
    final linkedBottom = math.max(p[_b('a')]!.y, p[_b('b')]!.y);
    expect(p[_b('solo2')]!.y, greaterThan(linkedBottom));
    expect(p[_b('solo1')]!.y, greaterThan(linkedBottom));
    expect(
      p[_b('solo2')]!.x,
      lessThan(p[_b('solo1')]!.x),
      reason: 'input order',
    );
    l.moveNode(_b('solo1'), const GraphPoint(-500, -500));
    expect(l.frame.positions[_b('solo1')], const GraphPoint(-500, -500));
  });
}
