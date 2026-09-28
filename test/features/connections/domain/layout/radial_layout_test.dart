import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/radial_layout.dart';

const _focus = NodeRef(ConnectionKind.buddy, 'me');

ConnectionNode _n(ConnectionKind k, String id) =>
    ConnectionNode(ref: NodeRef(k, id), label: id, diveCount: 1);

ConnectionEdge _spoke(NodeRef to, int w) => ConnectionEdge(
  source: _focus,
  target: to,
  weight: w,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

double _angle(GraphPoint p) => math.atan2(p.y, p.x);

void main() {
  test('focus at origin, neighbours on the first ring', () {
    final b1 = _n(ConnectionKind.buddy, 'b1');
    final b2 = _n(ConnectionKind.buddy, 'b2');
    final f = RadialLayout.compute(
      focus: _focus,
      nodes: [_n(ConnectionKind.buddy, 'me'), b1, b2],
      edges: [_spoke(b1.ref, 3), _spoke(b2.ref, 1)],
    );
    expect(f.settled, isTrue);
    expect(f.positions[_focus], GraphPoint.zero);
    expect(f.positions[b1.ref]!.length, closeTo(170, 0.01));
    expect(f.positions[b2.ref]!.length, closeTo(170, 0.01));
  });

  test('kinds occupy contiguous arcs and heavier neighbours come first', () {
    final sites = [for (var i = 0; i < 4; i++) _n(ConnectionKind.site, 's$i')];
    final buddies = [
      for (var i = 0; i < 4; i++) _n(ConnectionKind.buddy, 'b$i'),
    ];
    final f = RadialLayout.compute(
      focus: _focus,
      nodes: [_n(ConnectionKind.buddy, 'me'), ...sites, ...buddies],
      edges: [
        for (var i = 0; i < 4; i++) _spoke(sites[i].ref, 4 - i),
        for (var i = 0; i < 4; i++) _spoke(buddies[i].ref, i + 1),
      ],
    );
    final siteAngles = sites.map((s) => _angle(f.positions[s.ref]!)).toList();
    final buddyAngles = buddies
        .map((b) => _angle(f.positions[b.ref]!))
        .toList();
    // Buddies (kind index 0) start at angle 0 and fill the first half turn.
    expect(buddyAngles.every((a) => a >= -0.01 && a <= math.pi + 0.01), isTrue);
    expect(siteAngles.every((a) => a >= math.pi - 0.01 || a <= 0.01), isTrue);
    // Heavier first within the buddy arc: b3 (weight 4) has the smallest
    // angle.
    final heaviest = buddies.reduce(
      (a, b) =>
          _angle(f.positions[a.ref]!) <= _angle(f.positions[b.ref]!) ? a : b,
    );
    expect(heaviest.ref.id, 'b3');
  });

  test('spills to a second ring when an arc is full', () {
    final many = [for (var i = 0; i < 40; i++) _n(ConnectionKind.buddy, 'b$i')];
    final f = RadialLayout.compute(
      focus: _focus,
      nodes: [_n(ConnectionKind.buddy, 'me'), ...many],
      edges: [for (final m in many) _spoke(m.ref, 1)],
    );
    final radii = many.map((m) => f.positions[m.ref]!.length.round()).toSet();
    expect(radii, containsAll([170, 290]));
  });

  test('a lone focus is a single point', () {
    final f = RadialLayout.compute(
      focus: _focus,
      nodes: [_n(ConnectionKind.buddy, 'me')],
      edges: const [],
    );
    expect(f.positions, {_focus: GraphPoint.zero});
  });

  test('farther hops sit on outer rings', () {
    ConnectionNode hop(ConnectionKind k, String id, int h) =>
        ConnectionNode(ref: NodeRef(k, id), label: id, diveCount: 1, hop: h);
    final near = [
      for (var i = 0; i < 30; i++) hop(ConnectionKind.buddy, 'n$i', 1),
    ];
    final far = [
      for (var i = 0; i < 5; i++) hop(ConnectionKind.site, 'f$i', 2),
    ];
    final f = RadialLayout.compute(
      focus: _focus,
      nodes: [_n(ConnectionKind.buddy, 'me'), ...near, ...far],
      edges: [
        for (final n in [...near, ...far]) _spoke(n.ref, 1),
      ],
    );
    final nearMax = near
        .map((n) => f.positions[n.ref]!.length)
        .reduce(math.max);
    final farMin = far.map((n) => f.positions[n.ref]!.length).reduce(math.min);
    expect(farMin, greaterThan(nearMax));
  });
}
