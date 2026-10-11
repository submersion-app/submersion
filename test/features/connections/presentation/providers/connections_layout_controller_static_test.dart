import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/layout/circle_layout.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    for (final id in ['a', 'b', 'c'])
      ConnectionNode(ref: _b(id), label: id, diveCount: 1),
  ],
  edges: [
    ConnectionEdge(
      source: _b('a'),
      target: _b('b'),
      weight: 2,
      firstDiveAt: DateTime.utc(2024),
      lastDiveAt: DateTime.utc(2024),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectionsLayoutController c;
  setUp(() => c = ConnectionsLayoutController(vsync: const TestVSync()));
  tearDown(() => c.dispose());

  test('a static layout is settled at once and matches its function', () {
    c.setGraph(_graph, layout: ConnectionsLayout.circle);
    expect(c.settled, isTrue);
    expect(c.layout, ConnectionsLayout.circle);
    expect(
      c.frame.positions,
      CircleLayout.compute(nodes: _graph.nodes).positions,
    );
  });

  test('moveNode pins one node in a static layout; relayout releases', () {
    c.setGraph(_graph, layout: ConnectionsLayout.columns);
    final before = c.frame.positions;
    c.moveNode(_b('a'), const GraphPoint(999, 999));
    expect(c.frame.positions[_b('a')], const GraphPoint(999, 999));
    expect(c.frame.positions[_b('b')], before[_b('b')]);
    expect(c.canRelayout.value, isTrue);
    c.relayout();
    expect(c.canRelayout.value, isFalse);
    expect(c.frame.positions, before);
  });

  test('moveNode works in the radial layout', () {
    c.setGraph(_graph, layout: ConnectionsLayout.radial, focus: _b('a'));
    c.moveNode(_b('b'), const GraphPoint(5, 6));
    expect(c.frame.positions[_b('b')], const GraphPoint(5, 6));
  });

  test('a new graph, layout or spacing releases every pin', () {
    c.setGraph(_graph, layout: ConnectionsLayout.circle);
    c.moveNode(_b('a'), const GraphPoint(1, 1));
    c.setGraph(_graph, layout: ConnectionsLayout.circle, spacing: 1.5);
    expect(c.canRelayout.value, isFalse);
  });

  test('switching layout morphs over the refocus duration', () {
    c.setGraph(_graph, layout: ConnectionsLayout.columns);
    c.setGraph(_graph, layout: ConnectionsLayout.circle, animate: true);
    expect(c.settled, isFalse);
    c.stepForTest(null, kRefocusDuration);
    expect(c.settled, isTrue);
    expect(
      c.frame.positions,
      CircleLayout.compute(nodes: _graph.nodes).positions,
    );
  });

  test('dragging during a morph lands on the target layout', () {
    c.setGraph(_graph, layout: ConnectionsLayout.columns);
    c.setGraph(_graph, layout: ConnectionsLayout.circle, animate: true);
    c.moveNode(_b('a'), const GraphPoint(7, 7));
    final target = CircleLayout.compute(nodes: _graph.nodes).positions;
    expect(c.settled, isTrue);
    expect(c.frame.positions[_b('a')], const GraphPoint(7, 7));
    expect(c.frame.positions[_b('b')], target[_b('b')]);
  });

  test('web can always be laid out again, pinned or not', () {
    c.setGraph(_graph, layout: ConnectionsLayout.web);
    expect(c.canRelayout.value, isTrue);
    c.moveNode(_b('a'), const GraphPoint(3, 3));
    expect(c.canRelayout.value, isTrue);
  });

  test('clusters returns at once and settles over ticks', () {
    final triangle = ConnectionGraph(
      nodes: [
        for (final id in ['a', 'b', 'c', 'd'])
          ConnectionNode(ref: _b(id), label: id, diveCount: 1),
      ],
      edges: [
        for (final (x, y) in [('a', 'b'), ('b', 'c'), ('a', 'c'), ('c', 'd')])
          ConnectionEdge(
            source: _b(x),
            target: _b(y),
            weight: 2,
            firstDiveAt: DateTime.utc(2024),
            lastDiveAt: DateTime.utc(2024),
          ),
      ],
    );
    c.setGraph(triangle, layout: ConnectionsLayout.clusters);
    expect(c.layout, ConnectionsLayout.clusters);
    expect(c.settled, isFalse);
    while (!c.settled) {
      c.stepForTest();
    }
    expect(c.frame.positions.length, 4);
    c.moveNode(_b('a'), const GraphPoint(400, 400));
    expect(c.frame.positions[_b('a')], const GraphPoint(400, 400));
  });

  test('clusters uses the groups it is given instead of finding its own', () {
    // Label propagation would make one group of this triangle plus tail;
    // the caller's groups split it in two.
    final graph = ConnectionGraph(
      nodes: [
        for (final id in ['a', 'b', 'c', 'd'])
          ConnectionNode(ref: _b(id), label: id, diveCount: 1),
      ],
      edges: [
        for (final (x, y) in [('a', 'b'), ('b', 'c'), ('a', 'c'), ('c', 'd')])
          ConnectionEdge(
            source: _b(x),
            target: _b(y),
            weight: 2,
            firstDiveAt: DateTime.utc(2024),
            lastDiveAt: DateTime.utc(2024),
          ),
      ],
    );
    final groups = GraphGroups(
      groupOf: {_b('a'): 0, _b('d'): 0, _b('b'): 1, _b('c'): 1},
      count: 2,
    );
    c.setGraph(graph, layout: ConnectionsLayout.clusters, groups: groups);
    while (!c.settled) {
      c.stepForTest();
    }
    final p = c.frame.positions;
    GraphBounds box(List<String> ids) =>
        GraphBounds.of([for (final id in ids) p[_b(id)]!]);
    final ad = box(['a', 'd']);
    final bc = box(['b', 'c']);
    final apart =
        ad.right < bc.left ||
        bc.right < ad.left ||
        ad.bottom < bc.top ||
        bc.bottom < ad.top;
    expect(apart, isTrue);
  });
}
