import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/circle_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

ConnectionNode _n(ConnectionKind k, String id, int dives) =>
    ConnectionNode(ref: NodeRef(k, id), label: id, diveCount: dives);

/// Clockwise angle from the top, 0 to 2 pi.
double _angle(GraphPoint p) =>
    (math.atan2(p.y, p.x) + math.pi / 2) % (2 * math.pi);

void main() {
  test('an empty graph lays out nothing', () {
    expect(CircleLayout.compute(nodes: const []).positions, isEmpty);
  });

  test('one node sits on the ring with finite coordinates', () {
    final p = CircleLayout.compute(
      nodes: [_n(ConnectionKind.buddy, 'a', 1)],
    ).positions.values.single;
    expect(p.isFinite, isTrue);
    expect(p.length, closeTo(CircleLayout.minRadius, 1e-6));
  });

  test('kinds form contiguous arcs, busiest first within a kind', () {
    final nodes = [
      _n(ConnectionKind.site, 's1', 1),
      _n(ConnectionKind.buddy, 'b1', 1),
      _n(ConnectionKind.site, 's2', 9),
      _n(ConnectionKind.buddy, 'b2', 5),
    ];
    final f = CircleLayout.compute(nodes: nodes);
    final order = [...nodes]
      ..sort(
        (a, b) =>
            _angle(f.positions[a.ref]!).compareTo(_angle(f.positions[b.ref]!)),
      );
    expect(order.map((n) => n.ref.id), ['b2', 'b1', 's2', 's1']);
  });

  test('neighbours never crowd closer than about one slot', () {
    final nodes = [
      for (var i = 0; i < 40; i++) _n(ConnectionKind.buddy, 'b$i', 40 - i),
    ];
    final f = CircleLayout.compute(nodes: nodes);
    for (var i = 0; i < nodes.length; i++) {
      final a = f.positions[nodes[i].ref]!;
      final b = f.positions[nodes[(i + 1) % nodes.length].ref]!;
      expect(a.distanceTo(b), greaterThan(CircleLayout.slot * 0.95));
    }
  });

  test('the focus sits in the middle of the ring', () {
    final focus = _n(ConnectionKind.buddy, 'me', 1);
    final f = CircleLayout.compute(
      nodes: [focus, _n(ConnectionKind.site, 's', 3)],
      focus: focus.ref,
    );
    expect(f.positions[focus.ref], GraphPoint.zero);
    expect(
      f.positions[const NodeRef(ConnectionKind.site, 's')]!.length,
      closeTo(CircleLayout.minRadius, 1e-6),
    );
  });

  test('spacing scales the radius', () {
    final nodes = [
      _n(ConnectionKind.buddy, 'a', 1),
      _n(ConnectionKind.buddy, 'b', 1),
    ];
    final r1 = CircleLayout.compute(nodes: nodes).positions.values.first.length;
    final r2 = CircleLayout.compute(
      nodes: nodes,
      spacing: 2,
    ).positions.values.first.length;
    expect(r2, closeTo(r1 * 2, 1e-6));
  });

  test('tight spacing never squeezes neighbours closer than a slot', () {
    final nodes = [
      for (var i = 0; i < 40; i++) _n(ConnectionKind.buddy, 'b$i', 40 - i),
    ];
    final f = CircleLayout.compute(nodes: nodes, spacing: 0.6);
    for (var i = 0; i < nodes.length; i++) {
      final a = f.positions[nodes[i].ref]!;
      final b = f.positions[nodes[(i + 1) % nodes.length].ref]!;
      expect(a.distanceTo(b), greaterThan(CircleLayout.slot * 0.95));
    }
  });

  test('tight spacing still tightens a small ring', () {
    final nodes = [
      _n(ConnectionKind.buddy, 'a', 1),
      _n(ConnectionKind.buddy, 'b', 1),
    ];
    final tight = CircleLayout.compute(
      nodes: nodes,
      spacing: 0.6,
    ).positions.values.first.length;
    expect(tight, closeTo(CircleLayout.minRadius * 0.6, 1e-6));
  });
}
