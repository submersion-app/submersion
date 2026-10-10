import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/stroke_strip.dart';

(double, double, double) _red(int _) => (1, 0, 0);

List<double> _pointOf(List<double> positions, int pair) =>
    positions.sublist(pair * 6, pair * 6 + 3);

void main() {
  group('buildStrokeStrip', () {
    test('one pair at each end, two on every interior point', () {
      final mesh = buildStrokeStrip(
        xyz: [0, 0, 0, 1, 0, 0, 2, 1, 0, 3, 1, 0],
        strokeHalfWidthPx: 1.5,
        colorAt: _red,
      );
      expect(mesh.strokeHalfWidthPx, 1.5);
      expect(mesh.vertexCount, 2 * 6);
      expect(mesh.indices, hasLength(5 * 6));
      expect(mesh.sortHeights, isNull);
      // Pair k sits on point 0, the last point, or point (k + 1) ~/ 2.
      const expected = [0, 1, 1, 2, 2, 3];
      for (var k = 0; k < 6; k++) {
        final i = expected[k];
        expect(_pointOf(mesh.positions, k), [i.toDouble(), i < 2 ? 0 : 1, 0]);
        expect(
          mesh.positions.sublist(k * 6 + 3, k * 6 + 6),
          _pointOf(mesh.positions, k),
        );
      }
    });

    test('a closed line gets two pairs on its closing point, at the first '
        'point exactly', () {
      // A triangle whose last point lands back on its first within the
      // closing tolerance but not exactly.
      final mesh = buildStrokeStrip(
        xyz: [0, 0, 0, 4, 0, 0, 2, 3, 0, 0.00005, 0, 0],
        strokeHalfWidthPx: 1,
        colorAt: _red,
      );
      expect(mesh.vertexCount, 2 * 7);
      expect(_pointOf(mesh.positions, 5), [0, 0, 0]);
      expect(_pointOf(mesh.positions, 6), [0, 0, 0]);
      expect(_pointOf(mesh.positions, 0), [0, 0, 0]);
    });

    test('a line that merely ends near its start is open', () {
      final mesh = buildStrokeStrip(
        xyz: [0, 0, 0, 4, 0, 0, 2, 3, 0, 0.01, 0, 0],
        strokeHalfWidthPx: 1,
        colorAt: _red,
      );
      expect(mesh.vertexCount, 2 * 6);
      final p = _pointOf(mesh.positions, 5);
      expect(p[0], closeTo(0.01, 1e-6));
      expect(p[1], 0);
      expect(p[2], 0);
    });

    test('colors come per point and sort heights per vertex', () {
      final mesh = buildStrokeStrip(
        xyz: [0, 0, 0, 1, 0, 0, 2, 0, 0],
        strokeHalfWidthPx: 1,
        colorAt: (i) => (i / 2, 0, 0),
        sortHeightAt: (i) => 10.0 + i,
        opacity: 0.5,
      );
      expect(mesh.opacity, 0.5);
      // Pairs: point 0, point 1, point 1, point 2.
      expect(mesh.colors[0], 0);
      expect(mesh.colors[6], 0.5);
      expect(mesh.colors[12], 0.5);
      expect(mesh.colors[18], 1);
      expect(mesh.sortHeights, [10, 10, 11, 11, 11, 11, 12, 12]);
    });

    test('fewer than two points give an empty mesh', () {
      final mesh = buildStrokeStrip(
        xyz: [0, 0, 0],
        strokeHalfWidthPx: 1,
        colorAt: _red,
      );
      expect(mesh.positions, isEmpty);
      expect(mesh.indices, isEmpty);
      expect(mesh.strokeHalfWidthPx, isNull);
    });
  });
}
