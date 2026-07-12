import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/terrain_builder.dart';

ReckonedPath pathWithDeepSpot() {
  final points = <ReckonedPoint>[];
  for (var i = 0; i <= 20; i++) {
    final depth = i == 10 ? 40.0 : 10.0;
    points.add(
      ReckonedPoint(
        east: i * 5.0,
        north: 0,
        depth: depth,
        timeSeconds: i * 30.0,
      ),
    );
  }
  return ReckonedPath(
    points: points,
    reconstructed: true,
    minEast: 0,
    maxEast: 100,
    minNorth: 0,
    maxNorth: 0,
    maxDepth: 40,
    durationSeconds: 600,
  );
}

SpatialProjection projFor(ReckonedPath p) => SpatialProjection(
  minEast: p.minEast,
  maxEast: p.maxEast,
  minNorth: p.minNorth,
  maxNorth: p.maxNorth,
  maxDepth: p.maxDepth,
);

SpatialTerrain buildFor(ReckonedPath p, {int res = 28}) => TerrainBuilder.build(
  path: p,
  projection: projFor(p),
  minEast: p.minEast,
  maxEast: p.maxEast,
  minNorth: p.minNorth,
  maxNorth: p.maxNorth,
  gridResolution: res,
);

void main() {
  test('terrain grid has the expected vertex/triangle counts', () {
    final terrain = buildFor(pathWithDeepSpot(), res: 16);
    expect(terrain.terrain.vertexCount, 16 * 16);
    expect(terrain.terrain.triangleCount, 15 * 15 * 2);
  });

  test('seafloor is deeper below the deep spot than at the shallow ends', () {
    final path = pathWithDeepSpot();
    final proj = projFor(path);
    final terrain = buildFor(path, res: 32);
    double yNearest(double x, double z) {
      var best = double.infinity;
      var bestY = 0.0;
      for (var i = 0; i < terrain.terrain.vertexCount; i++) {
        final px = terrain.terrain.positions[i * 3];
        final pz = terrain.terrain.positions[i * 3 + 2];
        final d = (px - x) * (px - x) + (pz - z) * (pz - z);
        if (d < best) {
          best = d;
          bestY = terrain.terrain.positions[i * 3 + 1];
        }
      }
      return bestY;
    }

    final deepY = yNearest(proj.xOf(50), proj.zOf(0));
    final shallowY = yNearest(proj.xOf(0), proj.zOf(0));
    expect(deepY, lessThan(shallowY)); // deeper spot sits lower
  });

  test('water plane sits at the waterline', () {
    final terrain = buildFor(pathWithDeepSpot());
    for (var i = 0; i < terrain.water.vertexCount; i++) {
      expect(terrain.water.positions[i * 3 + 1], 0);
    }
    expect(terrain.water.opacity, lessThan(0.5));
  });
}
