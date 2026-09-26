import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionNode _node(String id, int dives) =>
    ConnectionNode(ref: _b(id), label: id, diveCount: dives);

ConnectionEdge _edge(String a, String b, int w) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: w,
  firstDiveAt: DateTime.utc(2024, 1, 1),
  lastDiveAt: DateTime.utc(2024, 6, 1),
);

void main() {
  final graph = ConnectionGraph(
    nodes: [_node('a', 5), _node('b', 5), _node('c', 2), _node('d', 9)],
    edges: [_edge('a', 'b', 3), _edge('b', 'c', 1), _edge('a', 'c', 1)],
  );

  test('weightedDegree sums the weights of touching edges', () {
    expect(graph.weightedDegree(_b('a')), 4);
    expect(graph.weightedDegree(_b('b')), 4);
    expect(graph.weightedDegree(_b('d')), 0);
  });

  test('trimmed keeps top nodes by dive count, then degree, then id', () {
    final t = graph.trimmed(2);
    expect(t.nodes.map((n) => n.ref.id), ['d', 'a']);
    expect(t.hiddenNodeCount, 2);
    expect(t.edges, isEmpty, reason: 'edges to trimmed nodes are dropped');
  });

  test('trimmed keeps the focus even when it ranks below the budget', () {
    final t = graph.trimmed(2, keep: _b('c'));
    expect(t.nodes.map((n) => n.ref.id).toSet(), {'d', 'c'});
    expect(t.hiddenNodeCount, 2);
  });

  test('trimmed is the identity when the budget is not exceeded', () {
    expect(identical(graph.trimmed(4), graph), isTrue);
    expect(graph.trimmed(4).hiddenNodeCount, 0);
  });

  test('maxDiveCount and maxWeight are zero on an empty graph', () {
    expect(ConnectionGraph.empty.maxDiveCount, 0);
    expect(ConnectionGraph.empty.maxWeight, 0);
    expect(ConnectionGraph.empty.isEmpty, isTrue);
  });

  test('edge helpers know both ends', () {
    final e = _edge('a', 'b', 1);
    expect(e.touches(_b('a')), isTrue);
    expect(e.otherEnd(_b('a')), _b('b'));
    expect(e.otherEnd(_b('b')), _b('a'));
    expect(e.otherEnd(_b('z')), isNull);
  });

  test('node equality compares photos by identity, not by bytes', () {
    final bytesA = Uint8List.fromList(List.filled(64, 7));
    final bytesB = Uint8List.fromList(List.filled(64, 7));
    final a = ConnectionNode(
      ref: _b('x'),
      label: 'X',
      diveCount: 1,
      photo: bytesA,
    );
    expect(
      a,
      ConnectionNode(ref: _b('x'), label: 'X', diveCount: 1, photo: bytesA),
    );
    expect(
      a ==
          ConnectionNode(ref: _b('x'), label: 'X', diveCount: 1, photo: bytesB),
      isFalse,
    );
  });
}
