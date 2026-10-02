import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/graph_summary.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);
ConnectionNode _n(NodeRef r, int dives) =>
    ConnectionNode(ref: r, label: r.id, diveCount: dives);
ConnectionEdge _e(NodeRef a, NodeRef b, int w, {int year = 2024}) =>
    ConnectionEdge(
      source: a,
      target: b,
      weight: w,
      firstDiveAt: DateTime.utc(2020),
      lastDiveAt: DateTime.utc(year),
    );

void main() {
  final graph = ConnectionGraph(
    nodes: [
      _n(_b('kiyan'), 34),
      _n(_b('sharon'), 20),
      _n(_b('lou'), 3),
      _n(_s('pier'), 14),
    ],
    edges: [
      _e(_b('kiyan'), _b('sharon'), 12),
      _e(_b('kiyan'), _s('pier'), 9),
      _e(_b('sharon'), _s('pier'), 4),
      _e(_b('kiyan'), _b('lou'), 2),
    ],
  );

  test('map summary: counts, connections, most connected, strongest', () {
    final s = GraphSummary.of(graph);
    expect(s.countsByKind, {ConnectionKind.buddy: 3, ConnectionKind.site: 1});
    expect(s.connectionCount, 4);
    expect(s.mostConnected!.ref, _b('kiyan'));
    expect(s.mostConnectedDegree, 23);
    expect(s.strongest!.weight, 12);
    expect(s.entitiesAround, 4);
    expect(s.closest, isNull);
  });

  test('around summary excludes the focus and finds the closest', () {
    final s = GraphSummary.of(graph, focus: _b('kiyan'));
    expect(s.entitiesAround, 3);
    expect(s.countsByKind, {ConnectionKind.buddy: 2, ConnectionKind.site: 1});
    expect(s.closest!.ref, _b('sharon'));
    expect(s.closestWeight, 12);
    expect(s.mostConnected!.ref, _b('sharon'));
  });

  test('ties in strength go to the more recent pair', () {
    final g = ConnectionGraph(
      nodes: [_n(_b('a'), 1), _n(_b('b'), 1), _n(_b('c'), 1)],
      edges: [
        _e(_b('a'), _b('b'), 5, year: 2020),
        _e(_b('a'), _b('c'), 5, year: 2025),
      ],
    );
    expect(GraphSummary.of(g).strongest!.target, _b('c'));
  });

  test('an empty graph summarises to nothing', () {
    final s = GraphSummary.of(ConnectionGraph.empty);
    expect(s.countsByKind, isEmpty);
    expect(s.connectionCount, 0);
    expect(s.mostConnected, isNull);
    expect(s.strongest, isNull);
  });
}
