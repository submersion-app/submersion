import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

MeshData triangle() => MeshData(
  positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
  indices: Uint32List.fromList([0, 1, 2]),
  colors: Float32List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 1]),
);

void main() {
  group('ScrubPath.positionAt', () {
    const path = ScrubPath(
      normalizedTimes: [0.0, 0.5, 1.0],
      xs: [0.0, 5.0, 10.0],
      ys: [0.0, -3.0, 0.0],
    );

    test('interpolates x and y over the normalized-time axis', () {
      final p = path.positionAt(0.25)!;
      expect(p.dx, closeTo(2.5, 1e-9));
      expect(p.dy, closeTo(-1.5, 1e-9));
    });

    test('clamps at the ends', () {
      expect(path.positionAt(-1)!.dx, 0.0);
      expect(path.positionAt(2)!.dx, 10.0);
    });

    test('returns null when empty', () {
      const empty = ScrubPath(normalizedTimes: [], xs: [], ys: []);
      expect(empty.positionAt(0.5), isNull);
    });
  });

  group('Scene3d', () {
    test('exposes layers, markers, bounds and scrub path', () {
      const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 10);
      final scene = Scene3d(
        layers: [
          SceneLayer(triangle()),
          SceneLayer(triangle(), overlay: SceneOverlay.strata),
        ],
        markers: const [],
        bounds: bounds,
        scrubPath: const ScrubPath(
          normalizedTimes: [0, 1],
          xs: [0, 10],
          ys: [0, 0],
        ),
      );
      expect(scene.layers.length, 2);
      expect(scene.layers.first.overlay, isNull);
      expect(scene.layers[1].overlay, SceneOverlay.strata);
      expect(scene.scrubPath, isNotNull);
    });
  });
}
