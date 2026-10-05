import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
ConnectionNode _n(String id) =>
    ConnectionNode(ref: _b(id), label: id, diveCount: 1);
ConnectionEdge _e(String a, String b) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: 1,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

final _graph = ConnectionGraph(
  nodes: [_n('a'), _n('b'), _n('c')],
  edges: [_e('a', 'b'), _e('b', 'c')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web mode steps toward a settled frame and notifies', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    var notified = 0;
    c.addListener(() => notified++);
    c.setGraph(_graph, mode: GraphLayoutMode.web);
    expect(c.frame.positions.length, 3);
    expect(c.settled, isFalse);
    while (!c.settled) {
      c.stepForTest();
    }
    expect(notified, greaterThan(1));
  });

  test('ego mode is settled immediately with the focus at the origin', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(_graph, mode: GraphLayoutMode.ego, focus: _b('b'));
    expect(c.settled, isTrue);
    expect(c.frame.positions[_b('b')], GraphPoint.zero);
    expect(c.mode, GraphLayoutMode.ego);
  });

  test('moveNode pins and relayout releases', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(_graph, mode: GraphLayoutMode.web);
    while (!c.settled) {
      c.stepForTest();
    }
    c.moveNode(_b('a'), const GraphPoint(900, 900));
    c.stepForTest(5);
    expect(
      c.frame.positions[_b('a')]!.distanceTo(const GraphPoint(900, 900)),
      lessThan(0.001),
    );
    c.relayout();
    while (!c.settled) {
      c.stepForTest();
    }
    expect(
      c.frame.positions[_b('a')]!.distanceTo(const GraphPoint(900, 900)),
      greaterThan(1),
    );
  });

  test('a warm start keeps a node near its previous place', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(_graph, mode: GraphLayoutMode.web);
    while (!c.settled) {
      c.stepForTest();
    }
    final before = c.frame.positions[_b('a')]!;
    c.setGraph(
      _graph.copyWith(
        nodes: [..._graph.nodes, _n('d')],
        edges: [..._graph.edges, _e('c', 'd')],
      ),
      mode: GraphLayoutMode.web,
    );
    c.stepForTest(3);
    expect(c.frame.positions[_b('a')]!.distanceTo(before), lessThan(80));
  });

  test('an empty graph yields an empty settled frame', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(ConnectionGraph.empty, mode: GraphLayoutMode.web);
    expect(c.settled, isTrue);
    expect(c.frame.positions, isEmpty);
  });

  test('an animated refocus morphs over 450 ms, then settles', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(_graph, mode: GraphLayoutMode.web);
    while (!c.settled) {
      c.stepForTest();
    }
    final before = c.frame.positions[_b('a')]!;
    c.setGraph(
      _graph,
      mode: GraphLayoutMode.ego,
      focus: _b('b'),
      animate: true,
    );
    expect(c.settled, isFalse);
    expect(c.frame.positions[_b('a')], before);
    c.stepForTest(0, const Duration(milliseconds: 225));
    final mid = c.frame.positions[_b('a')]!;
    expect(mid, isNot(before));
    expect(c.settled, isFalse);
    c.stepForTest(0, const Duration(milliseconds: 250));
    expect(c.settled, isTrue);
    expect(c.frame.positions[_b('b')], GraphPoint.zero);
  });

  test('without animate the ego layout is immediate', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(_graph, mode: GraphLayoutMode.web);
    c.setGraph(_graph, mode: GraphLayoutMode.ego, focus: _b('b'));
    expect(c.settled, isTrue);
  });
  group('settleNow', () {
    test('finishes a running force layout and notifies', () {
      final c = ConnectionsLayoutController(vsync: const TestVSync());
      addTearDown(c.dispose);
      c.setGraph(_graph, mode: GraphLayoutMode.web);
      expect(c.settled, isFalse);
      var notified = 0;
      c.addListener(() => notified++);
      final frame = c.settleNow();
      expect(frame.settled, isTrue);
      expect(c.settled, isTrue);
      expect(identical(c.frame, frame), isTrue);
      expect(notified, 1);
    });

    test('jumps a refocus morph to its target, every node fully grown', () {
      final c = ConnectionsLayoutController(vsync: const TestVSync());
      addTearDown(c.dispose);
      c.setGraph(_graph, mode: GraphLayoutMode.ego, focus: _b('a'));
      c.setGraph(
        _graph,
        mode: GraphLayoutMode.ego,
        focus: _b('c'),
        animate: true,
      );
      expect(c.settled, isFalse, reason: 'the morph is in flight');
      final frame = c.settleNow();
      expect(c.settled, isTrue);
      expect(frame.positions[_b('c')], GraphPoint.zero);
      for (final n in _graph.nodes) {
        expect(frame.appearOf(n.ref), 1);
      }
    });

    test('returns the frame as is when already settled', () {
      final c = ConnectionsLayoutController(vsync: const TestVSync());
      addTearDown(c.dispose);
      c.setGraph(_graph, mode: GraphLayoutMode.ego, focus: _b('b'));
      final before = c.frame;
      expect(identical(c.settleNow(), before), isTrue);
    });
  });
}
