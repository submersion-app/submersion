import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_hit_tester.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  final frame = LayoutFrame.fromPositions({
    _b('a'): const GraphPoint(0, 0),
    _b('b'): const GraphPoint(200, 0),
  }, settled: true);
  const viewport = GraphViewport(scale: 1, offset: Offset(100, 100));
  double radius(NodeRef _) => 10;

  test('picks the nearest node within radius plus slop', () {
    expect(
      ConnectionsHitTester.hitNode(
        const Offset(105, 104),
        frame: frame,
        viewport: viewport,
        radiusOf: radius,
      ),
      _b('a'),
    );
    expect(
      ConnectionsHitTester.hitNode(
        const Offset(295, 100),
        frame: frame,
        viewport: viewport,
        radiusOf: radius,
      ),
      _b('b'),
    );
    expect(
      ConnectionsHitTester.hitNode(
        const Offset(200, 100),
        frame: frame,
        viewport: viewport,
        radiusOf: radius,
      ),
      isNull,
    );
  });

  test('a tiny node is still hittable within the minimum touch radius', () {
    double tiny(NodeRef _) => 2;
    expect(
      ConnectionsHitTester.hitNode(
        const Offset(120, 100),
        frame: frame,
        viewport: viewport,
        radiusOf: tiny,
      ),
      _b('a'),
      reason: '20 px away, inside minRadius 18 + slop 12',
    );
  });

  test('hits an edge near its midpoint and nothing far away', () {
    final edge = ConnectionEdge(
      source: _b('a'),
      target: _b('b'),
      weight: 1,
      firstDiveAt: DateTime.utc(2024),
      lastDiveAt: DateTime.utc(2024),
    );
    expect(
      ConnectionsHitTester.hitEdge(
        const Offset(200, 106),
        frame: frame,
        viewport: viewport,
        edges: [edge],
      ),
      edge,
    );
    expect(
      ConnectionsHitTester.hitEdge(
        const Offset(200, 140),
        frame: frame,
        viewport: viewport,
        edges: [edge],
      ),
      isNull,
    );
  });

  test('distanceToSegment handles the ends', () {
    const a = Offset(0, 0);
    const b = Offset(10, 0);
    expect(ConnectionsHitTester.distanceToSegment(const Offset(5, 3), a, b), 3);
    expect(
      ConnectionsHitTester.distanceToSegment(const Offset(-4, 0), a, b),
      4,
    );
    expect(
      ConnectionsHitTester.distanceToSegment(const Offset(13, 4), a, b),
      5,
    );
    expect(
      ConnectionsHitTester.distanceToSegment(const Offset(2, 2), a, a),
      closeTo(2.828, 0.001),
    );
  });
}
