import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);

ConnectionNode _n(NodeRef r) =>
    ConnectionNode(ref: r, label: r.id, diveCount: 1);

ConnectionEdge _e(NodeRef a, NodeRef b, int w) => ConnectionEdge(
  source: a,
  target: b,
  weight: w,
  firstDiveAt: DateTime.utc(2020),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  test('two triangles joined by a weak bridge are two groups', () {
    final r = [for (final id in 'abcdef'.split('')) _b(id)];
    final g = ConnectionGraph(
      nodes: [for (final x in r) _n(x)],
      edges: [
        _e(r[0], r[1], 3),
        _e(r[0], r[2], 3),
        _e(r[1], r[2], 3),
        _e(r[3], r[4], 3),
        _e(r[3], r[5], 3),
        _e(r[4], r[5], 3),
        _e(r[2], r[3], 1),
      ],
    );
    final groups = LabelPropagation.communities(g);
    expect(groups.count, 2);
    expect(groups.groupOf[r[0]], groups.groupOf[r[2]]);
    expect(groups.groupOf[r[3]], groups.groupOf[r[5]]);
    expect(groups.groupOf[r[0]], isNot(groups.groupOf[r[3]]));
  });

  test('a buddy-site map converges to one group', () {
    final g = ConnectionGraph(
      nodes: [_n(_b('b1')), _n(_b('b2')), _n(_s('s1')), _n(_s('s2'))],
      edges: [
        _e(_b('b1'), _s('s1'), 2),
        _e(_b('b2'), _s('s1'), 2),
        _e(_b('b1'), _s('s2'), 1),
      ],
    );
    final groups = LabelPropagation.communities(g);
    expect(groups.count, 1);
    expect(groups.groupOf.length, 4);
    expect(groups.groupOf.values.toSet(), {0});
  });

  test('isolated nodes get no group', () {
    final g = ConnectionGraph(
      nodes: [_n(_b('a')), _n(_b('b')), _n(_b('lonely'))],
      edges: [_e(_b('a'), _b('b'), 1)],
    );
    final groups = LabelPropagation.communities(g);
    expect(groups.count, 1);
    expect(groups.groupOf.containsKey(_b('lonely')), isFalse);
  });

  test('larger groups rank first and the result ignores input order', () {
    final big = [
      for (final id in ['p', 'q', 'r']) _b(id),
    ];
    final small = [_b('x'), _b('y')];
    final nodes = [
      for (final r in [...small, ...big]) _n(r),
    ];
    final edges = [
      _e(small[0], small[1], 5),
      _e(big[0], big[1], 1),
      _e(big[1], big[2], 1),
      _e(big[0], big[2], 1),
    ];
    final a = LabelPropagation.communities(
      ConnectionGraph(nodes: nodes, edges: edges),
    );
    final b = LabelPropagation.communities(
      ConnectionGraph(
        nodes: nodes.reversed.toList(),
        edges: edges.reversed.toList(),
      ),
    );
    expect(a.groupOf, b.groupOf);
    expect(a.groupOf[big[0]], 0);
    expect(a.groupOf[small[0]], 1);
  });

  test('an empty graph has no groups', () {
    expect(LabelPropagation.communities(ConnectionGraph.empty).count, 0);
  });

  test('the round cap returns the labels it has', () {
    final r = [for (final id in 'abcdef'.split('')) _b(id)];
    final g = ConnectionGraph(
      nodes: [for (final x in r) _n(x)],
      edges: [for (var i = 0; i < 5; i++) _e(r[i], r[i + 1], 1)],
    );
    final groups = LabelPropagation.communities(g, maxRounds: 1);
    expect(groups.groupOf.length, lessThanOrEqualTo(6));
    expect(groups.count, greaterThan(0));
  });
}
