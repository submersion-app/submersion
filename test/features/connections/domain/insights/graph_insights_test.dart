import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/graph_insights.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionEdge _e(String a, String b, int w, int firstYear, int lastYear) =>
    ConnectionEdge(
      source: _b(a),
      target: _b(b),
      weight: w,
      firstDiveAt: DateTime.utc(firstYear),
      lastDiveAt: DateTime.utc(lastYear),
    );

ConnectionGraph _graph(List<ConnectionEdge> edges) {
  final ids = {
    for (final e in edges) ...[e.source.id, e.target.id],
  };
  return ConnectionGraph(
    nodes: [
      for (final id in ids)
        ConnectionNode(ref: _b(id), label: id.toUpperCase(), diveCount: 1),
    ],
    edges: edges,
  );
}

List<InsightTile> _of(ConnectionGraph g, {NodeRef? focus}) =>
    GraphInsights.of(g, focus: focus, groups: LabelPropagation.communities(g));

InsightTile? _tile(List<InsightTile> tiles, InsightKind k) =>
    tiles.where((t) => t.kind == k).firstOrNull;

void main() {
  final g = _graph([
    _e('ana', 'bo', 9, 2015, 2025), // strongest
    _e('ana', 'cy', 3, 2012, 2014), // drifting: weight 3, last 2014
    _e('bo', 'cy', 1, 2010, 2011), // weight 1: never drifting
    _e('cy', 'dee', 2, 2024, 2025), // newest first dive
  ]);

  test('map mode: five tiles in order', () {
    final tiles = _of(g);
    expect(tiles.map((t) => t.kind), [
      InsightKind.mostConnected,
      InsightKind.strongestPair,
      InsightKind.newest,
      InsightKind.driftingApart,
      InsightKind.groups,
    ]);
    expect(_tile(tiles, InsightKind.mostConnected)!.node!.ref, _b('ana'));
    expect(_tile(tiles, InsightKind.mostConnected)!.value, 12);
    expect(_tile(tiles, InsightKind.strongestPair)!.edge!.weight, 9);
    expect(_tile(tiles, InsightKind.newest)!.edge!.target, _b('dee'));
    expect(_tile(tiles, InsightKind.driftingApart)!.edge!.target, _b('cy'));
    expect(_tile(tiles, InsightKind.groups)!.value, 1);
  });

  test('tiles target what they name', () {
    final tiles = _of(g);
    expect(
      _tile(tiles, InsightKind.mostConnected)!.target,
      NodeSelection(_b('ana')),
    );
    expect(
      _tile(tiles, InsightKind.strongestPair)!.target,
      EdgeSelection(_b('ana'), _b('bo')),
    );
    expect(_tile(tiles, InsightKind.groups)!.target, isNull);
  });

  test('drifting apart needs weight two or more', () {
    final tiles = _of(_graph([_e('a', 'b', 1, 2000, 2001)]));
    expect(_tile(tiles, InsightKind.driftingApart), isNull);
  });

  test('drifting apart ties go to the heavier edge', () {
    final tiles = _of(
      _graph([_e('a', 'b', 2, 2000, 2010), _e('c', 'd', 5, 2000, 2010)]),
    );
    expect(_tile(tiles, InsightKind.driftingApart)!.edge!.weight, 5);
  });

  test('a graph with no edges has no tiles; an empty graph neither', () {
    final lonely = ConnectionGraph(
      nodes: [ConnectionNode(ref: _b('a'), label: 'A', diveCount: 4)],
      edges: const [],
    );
    expect(_of(lonely), isEmpty);
    expect(_of(ConnectionGraph.empty), isEmpty);
  });

  test(
    'around mode: centre-relative tiles, the centre never most connected',
    () {
      final tiles = _of(g, focus: _b('ana'));
      expect(tiles.map((t) => t.kind), [
        InsightKind.closest,
        InsightKind.newest,
        InsightKind.driftingApart,
        InsightKind.mostConnected,
        InsightKind.groups,
      ]);
      final closest = _tile(tiles, InsightKind.closest)!;
      expect(closest.node!.ref, _b('bo'));
      expect(closest.value, 9);
      expect(closest.target, EdgeSelection(_b('ana'), _b('bo')));
      expect(_tile(tiles, InsightKind.newest)!.node!.ref, _b('bo'));
      expect(_tile(tiles, InsightKind.driftingApart)!.node!.ref, _b('cy'));
      expect(
        _tile(tiles, InsightKind.mostConnected)!.node!.ref,
        isNot(_b('ana')),
      );
    },
  );

  test(
    'around mode with only weight-one centre edges has no drifting tile',
    () {
      final tiles = _of(
        _graph([_e('ana', 'bo', 1, 2000, 2001), _e('bo', 'cy', 4, 2000, 2001)]),
        focus: _b('ana'),
      );
      expect(_tile(tiles, InsightKind.driftingApart), isNull);
      expect(_tile(tiles, InsightKind.mostConnected)!.node!.ref, _b('bo'));
    },
  );
}
