import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/dead_reckoning_service.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';

ReckonedPath reckon() {
  const n = 40;
  return const DeadReckoningService().reckon(
    times: [for (var i = 0; i < n; i++) (i * 15).toDouble()],
    depths: [for (var i = 0; i < n; i++) (i < 20 ? i * 2.0 : (40 - i) * 2.0)],
    headings: [for (var i = 0; i < n; i++) (i * 4).toDouble()],
    swimSpeedMps: 0.4,
  );
}

void main() {
  const service = SpatialGeometryService();

  test('assembles terrain, path, pins and water layers', () {
    final scene = service.build(reckon(), siteMaxDepth: 45);
    // terrain + ribbon + entry pin + exit pin + water.
    expect(scene.layers.length, 5);
    // Water is the translucent top layer.
    expect(scene.layers.last.mesh.opacity, lessThan(1.0));
    // A 3D scrub path (with Z) follows the diver.
    expect(scene.scrubPath, isNotNull);
    expect(scene.scrubPath!.zs, isNotNull);
  });

  test('scene Z range widens to fit the horizontal spread', () {
    final scene = service.build(reckon());
    expect(scene.bounds.sceneMinZ, lessThan(scene.bounds.sceneMaxZ));
    // Depth axis stays in the [-ySpan, 0] convention (water at 0).
    expect(scene.bounds.sceneMaxY, 0);
  });

  test('degenerate path yields an empty scene', () {
    final scene = service.build(
      const ReckonedPath(
        points: [],
        reconstructed: false,
        minEast: 0,
        maxEast: 0,
        minNorth: 0,
        maxNorth: 0,
        maxDepth: 0,
        durationSeconds: 0,
      ),
    );
    expect(scene.layers, isEmpty);
  });

  test('scrub cursor point is defined mid-dive', () {
    final scene = service.build(reckon());
    final p = scene.scrubPath!.sceneAt(0.5);
    expect(p, isNotNull);
    expect(p!.z, isNot(0)); // genuinely 3D placement
  });
}
