import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/path_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strip_indices.dart';

void main() {
  const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 30);
  final colors = Float32List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 1]);

  test('stripIndices yields two triangles per segment', () {
    expect(stripIndices(1), isEmpty);
    expect(stripIndices(3), [0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4]);
  });

  test(
    'tube has two crossed strips: 4 vertices and 4 triangles per sample',
    () {
      final mesh = PathBuilder.build(
        times: [0, 50, 100],
        depths: [0, 30, 0],
        zs: [-1, 0, 1],
        sampleColors: colors,
        bounds: bounds,
      );
      expect(mesh.vertexCount, 12);
      expect(mesh.triangleCount, 8);
    },
  );

  test(
    'strip A straddles Z and strip B straddles Y at the sample position',
    () {
      final mesh = PathBuilder.build(
        times: [0, 50, 100],
        depths: [0, 30, 0],
        zs: [-1, 0.5, 1],
        sampleColors: colors,
        bounds: bounds,
      );
      const h = SceneBounds.zHalfWidth;
      final p = mesh.positions;
      void near(int at, List<double> want) {
        for (var k = 0; k < want.length; k++) {
          expect(p[at + k], closeTo(want[k], 1e-6));
        }
      }

      // Sample 1: x = 5, y = -6, z = 0.5.
      near(6, [5, -6, 0.5 - h, 5, -6, 0.5 + h]);
      // Strip B starts at vertex 2n = 6 (18 floats); sample 1 is 6 floats in.
      near(18 + 6, [5, -6 - h, 0.5, 5, -6 + h, 0.5]);
    },
  );
}
