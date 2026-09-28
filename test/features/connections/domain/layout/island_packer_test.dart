import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/island_packer.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
ConnectionEdge _e(String a, String b) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: 1,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  test('components are found and ordered largest first', () {
    final nodes = [_b('a'), _b('b'), _b('c'), _b('x'), _b('y'), _b('solo')];
    final comps = IslandPacker.components(nodes, [
      _e('a', 'b'),
      _e('b', 'c'),
      _e('x', 'y'),
    ]);
    expect(comps.length, 3);
    expect(comps[0].toSet(), {_b('a'), _b('b'), _b('c')});
    expect(comps[1].toSet(), {_b('x'), _b('y')});
    expect(comps[2], [_b('solo')]);
  });

  test('component order is deterministic for equal sizes', () {
    final nodes = [_b('y'), _b('x'), _b('b'), _b('a')];
    final comps = IslandPacker.components(nodes, [_e('x', 'y'), _e('a', 'b')]);
    expect(comps[0].map((r) => r.id).toSet(), {'a', 'b'});
  });

  test('packed frames do not overlap', () {
    LayoutFrame square(double size) => LayoutFrame.fromPositions({
      _b('p$size'): GraphPoint.zero,
      _b('q$size'): GraphPoint(size, size),
    }, settled: true);
    final frames = [square(100), square(300), square(50)];
    final offsets = IslandPacker.pack(frames, gap: 20);
    expect(offsets.length, 3);
    final rects = [
      for (var i = 0; i < 3; i++)
        frames[i].bounds.translate(offsets[i].x, offsets[i].y),
    ];
    for (var i = 0; i < 3; i++) {
      for (var j = i + 1; j < 3; j++) {
        final a = rects[i];
        final b = rects[j];
        final overlap =
            a.left < b.right &&
            b.left < a.right &&
            a.top < b.bottom &&
            b.top < a.bottom;
        expect(overlap, isFalse, reason: 'islands $i and $j overlap');
      }
    }
  });
}
