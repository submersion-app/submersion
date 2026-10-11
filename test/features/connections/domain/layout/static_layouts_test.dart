import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/circle_layout.dart';
import 'package:submersion/features/connections/domain/layout/columns_layout.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/radial_layout.dart';
import 'package:submersion/features/connections/domain/layout/static_layouts.dart';
import 'package:submersion/features/connections/domain/layout/timeline_layout.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(
      ref: _b('a'),
      label: 'A',
      diveCount: 2,
      firstDiveAt: DateTime.utc(2020),
    ),
    ConnectionNode(
      ref: _b('b'),
      label: 'B',
      diveCount: 1,
      firstDiveAt: DateTime.utc(2022),
    ),
  ],
  edges: [
    ConnectionEdge(
      source: _b('a'),
      target: _b('b'),
      weight: 1,
      firstDiveAt: DateTime.utc(2022),
      lastDiveAt: DateTime.utc(2022),
    ),
  ],
);

Map<NodeRef, GraphPoint> _run(ConnectionsLayout l, {NodeRef? focus}) =>
    StaticLayouts.compute(l, graph: _graph, focus: focus).positions;

void main() {
  test('each static layout dispatches to its own function', () {
    expect(
      _run(ConnectionsLayout.circle),
      CircleLayout.compute(nodes: _graph.nodes).positions,
    );
    expect(
      _run(ConnectionsLayout.columns),
      ColumnsLayout.compute(nodes: _graph.nodes).positions,
    );
    expect(
      _run(ConnectionsLayout.timeline),
      TimelineLayout.compute(nodes: _graph.nodes).positions,
    );
    expect(
      _run(ConnectionsLayout.radial, focus: _b('a')),
      RadialLayout.compute(
        focus: _b('a'),
        nodes: _graph.nodes,
        edges: _graph.edges,
      ).positions,
    );
  });

  test('radial without a centre falls back to the ring', () {
    expect(
      _run(ConnectionsLayout.radial),
      CircleLayout.compute(nodes: _graph.nodes).positions,
    );
  });

  test('the live layouts are not computed here', () {
    expect(() => _run(ConnectionsLayout.web), throwsArgumentError);
    expect(() => _run(ConnectionsLayout.clusters), throwsArgumentError);
  });
}
