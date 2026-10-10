import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/force_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/radial_layout.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionEdge _e(NodeRef a, NodeRef b) => ConnectionEdge(
  source: a,
  target: b,
  weight: 1,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  test('force spacing scales the settled distance of a linked pair', () {
    double gap(double spacing) {
      final l = ForceLayout(
        nodes: [_b('a'), _b('b')],
        edges: [_e(_b('a'), _b('b'))],
        spacing: spacing,
      );
      while (!l.settled) {
        l.advance(50);
      }
      return l.frame.positions[_b('a')]!.distanceTo(
        l.frame.positions[_b('b')]!,
      );
    }

    expect(gap(2) / gap(1), inInclusiveRange(1.6, 2.4));
  });

  test('radial spacing scales the ring exactly', () {
    final nodes = [
      ConnectionNode(ref: _b('f'), label: 'F', diveCount: 1),
      ConnectionNode(ref: _b('n'), label: 'N', diveCount: 1),
    ];
    final edges = [_e(_b('f'), _b('n'))];
    double ring(double s) => RadialLayout.compute(
      focus: _b('f'),
      nodes: nodes,
      edges: edges,
      spacing: s,
    ).positions[_b('n')]!.length;
    expect(ring(2), closeTo(ring(1) * 2, 1e-6));
  });

  test('whole web spaces single nodes by the spacing', () {
    double singleGap(double s) {
      final f = WholeWebLayout(
        nodes: [_b('x'), _b('y')],
        edges: const [],
        spacing: s,
      ).frame;
      return f.positions[_b('x')]!.distanceTo(f.positions[_b('y')]!);
    }

    expect(singleGap(1), 90);
    expect(singleGap(1.5), 135);
  });

  test('hasPins follows moveNode and clearPins, singles included', () {
    final web = WholeWebLayout(
      nodes: [_b('a'), _b('b'), _b('lone')],
      edges: [_e(_b('a'), _b('b'))],
    );
    expect(web.hasPins, isFalse);
    web.moveNode(_b('a'), const GraphPoint(5, 5));
    expect(web.hasPins, isTrue);
    web.clearPins();
    expect(web.hasPins, isFalse);
    web.moveNode(_b('lone'), const GraphPoint(9, 9));
    expect(web.hasPins, isTrue);
  });
}
