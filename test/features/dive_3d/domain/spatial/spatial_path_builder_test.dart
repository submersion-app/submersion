import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_path_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';

ReckonedPath _path(List<(double east, double north, double depth)> pts) =>
    ReckonedPath(
      points: [
        for (final (i, p) in pts.indexed)
          ReckonedPoint(
            east: p.$1,
            north: p.$2,
            depth: p.$3,
            timeSeconds: i * 10.0,
          ),
      ],
      provenance: PathProvenance.measured,
      minEast: pts.map((p) => p.$1).reduce(math.min),
      maxEast: pts.map((p) => p.$1).reduce(math.max),
      minNorth: pts.map((p) => p.$2).reduce(math.min),
      maxNorth: pts.map((p) => p.$2).reduce(math.max),
      maxDepth: pts.map((p) => p.$3).reduce(math.max),
      durationSeconds: (pts.length - 1) * 10.0,
    );

void main() {
  final proj = SpatialProjection(
    minEast: -50,
    maxEast: 50,
    minNorth: -50,
    maxNorth: 50,
    maxDepth: 20,
  );

  group('SpatialPathBuilder.buildRibbon', () {
    test('is a canvas stroke, not a scene-unit ribbon (issue #3215)', () {
      // A width in scene units grew with the terrain when zooming in and
      // read as a band; the renderer now widens the pairs in pixels.
      final mesh = SpatialPathBuilder.buildRibbon(
        _path([(0, 0, 5), (10, 10, 5), (20, 10, 8)]),
        proj,
      );
      expect(mesh.strokeHalfWidthPx, SpatialPathBuilder.strokeHalfWidthPx);
      expect(mesh.positions, hasLength(3 * 6));
      expect(mesh.indices, hasLength(2 * 6));
    });

    test('puts both members of every pair on the projected route point', () {
      final pts = [(0.0, 0.0, 5.0), (10.0, 10.0, 5.0), (20.0, 10.0, 8.0)];
      final mesh = SpatialPathBuilder.buildRibbon(_path(pts), proj);
      for (final (i, p) in pts.indexed) {
        for (var s = 0; s < 2; s++) {
          final vi = i * 6 + s * 3;
          expect(mesh.positions[vi], closeTo(proj.xOf(p.$1), 1e-6));
          expect(mesh.positions[vi + 1], closeTo(proj.yOf(p.$3), 1e-6));
          expect(mesh.positions[vi + 2], closeTo(proj.zOf(p.$2), 1e-6));
        }
      }
    });

    test('colors the route yellow at the surface and orange at max depth', () {
      final mesh = SpatialPathBuilder.buildRibbon(
        _path([(0, 0, 0), (10, 0, 20)]),
        proj,
      );
      const shallow = Color(0xFFFDE047);
      const deep = Color(0xFFF97316);
      expect(mesh.colors[0], closeTo(shallow.r, 1e-6));
      expect(mesh.colors[1], closeTo(shallow.g, 1e-6));
      expect(mesh.colors[2], closeTo(shallow.b, 1e-6));
      expect(mesh.colors[9], closeTo(deep.r, 1e-6));
      expect(mesh.colors[10], closeTo(deep.g, 1e-6));
      expect(mesh.colors[11], closeTo(deep.b, 1e-6));
    });

    test('returns an empty mesh for fewer than two points', () {
      final mesh = SpatialPathBuilder.buildRibbon(_path([(0, 0, 5)]), proj);
      expect(mesh.positions, isEmpty);
      expect(mesh.indices, isEmpty);
      expect(mesh.colors, isEmpty);
      expect(mesh.strokeHalfWidthPx, isNull);
    });
  });
}
