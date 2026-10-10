import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/cluster_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionEdge _e(String a, String b) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: 3,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

final _graph = ConnectionGraph(
  nodes: [
    for (final id in ['a1', 'a2', 'a3', 'z1', 'z2', 'z3', 'lone'])
      ConnectionNode(ref: _b(id), label: id, diveCount: 1),
  ],
  edges: [
    _e('a1', 'a2'),
    _e('a2', 'a3'),
    _e('a1', 'a3'),
    _e('z1', 'z2'),
    _e('z2', 'z3'),
    _e('z1', 'z3'),
  ],
);

void main() {
  test('each group gets its own island, islands do not overlap', () {
    final f = ClusterLayout.compute(graph: _graph);
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

  test('an ungrouped node goes below the islands', () {
    final f = ClusterLayout.compute(graph: _graph);
    final lowest = [
      for (final id in ['a1', 'a2', 'a3', 'z1', 'z2', 'z3'])
        f.positions[_b(id)]!.y,
    ].reduce((x, y) => x > y ? x : y);
    expect(f.positions[_b('lone')]!.y, greaterThan(lowest));
  });

  test('is deterministic and settled', () {
    final f1 = ClusterLayout.compute(graph: _graph);
    final f2 = ClusterLayout.compute(graph: _graph);
    expect(f1.positions, f2.positions);
    expect(f1.settled, isTrue);
  });

  test('an empty graph lays out nothing', () {
    expect(
      ClusterLayout.compute(graph: ConnectionGraph.empty).positions,
      isEmpty,
    );
  });
}
