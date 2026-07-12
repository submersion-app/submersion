import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ribbon_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

void main() {
  const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 10);
  final times = [0.0, 50.0, 100.0];
  final depths = [0.0, 10.0, 0.0];
  final colors = Float32List.fromList([
    1, 0, 0, // sample 0: red
    0, 1, 0, // sample 1: green
    0, 0, 1, // sample 2: blue
  ]);

  group('RibbonBuilder.build', () {
    test('emits two vertices per sample and two triangles per segment', () {
      final mesh = RibbonBuilder.build(
        times: times,
        depths: depths,
        sampleColors: colors,
        bounds: bounds,
      );
      expect(mesh.vertexCount, 6);
      expect(mesh.triangleCount, 4);
    });

    test('vertex pair straddles z axis at the sample position', () {
      final mesh = RibbonBuilder.build(
        times: times,
        depths: depths,
        sampleColors: colors,
        bounds: bounds,
      );
      // Sample 1: t=50 -> x=5, d=10 -> y=-6
      expect(mesh.positions[6], 5.0); // v2.x
      expect(mesh.positions[7], -6.0); // v2.y
      expect(mesh.positions[8], closeTo(-SceneBounds.zHalfWidth, 1e-6));
      expect(mesh.positions[11], closeTo(SceneBounds.zHalfWidth, 1e-6));
    });

    test('both vertices of a pair share the sample color', () {
      final mesh = RibbonBuilder.build(
        times: times,
        depths: depths,
        sampleColors: colors,
        bounds: bounds,
      );
      expect(mesh.colors.sublist(0, 3), mesh.colors.sublist(3, 6));
      expect(mesh.colors[3], 1.0); // sample 0 red
      expect(mesh.colors[10], 1.0); // sample 1 green
    });

    test('applies the opacity argument to the mesh', () {
      final mesh = RibbonBuilder.build(
        times: const [0.0, 60.0],
        depths: const [0.0, 10.0],
        sampleColors: Float32List.fromList(const [1, 0, 0, 1, 0, 0]),
        bounds: const SceneBounds(durationSeconds: 60, maxDepthMeters: 10),
        opacity: 0.55,
      );
      expect(mesh.opacity, closeTo(0.55, 1e-9));
    });
  });

  group('RibbonBuilder.curtain', () {
    test('drops from the ribbon to the max-depth floor with translucency', () {
      final mesh = RibbonBuilder.curtain(
        times: times,
        depths: depths,
        bounds: bounds,
      );
      expect(mesh.vertexCount, 6);
      // Vertex pair: top at profile depth, bottom at floor.
      expect(mesh.positions[1], 0.0); // sample 0 top y
      expect(mesh.positions[4], -SceneBounds.ySpan); // sample 0 bottom y
      expect(mesh.opacity, lessThan(0.5));
    });
  });
}
