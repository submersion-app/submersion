import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/contour_builder.dart';
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
    test('no wider than a major contour ribbon (issue #3215)', () {
      // The track used to be 0.08, 2.7x the major isobath width, and read
      // as a band rather than a line next to the contours.
      expect(
        SpatialPathBuilder.ribbonHalfWidth,
        lessThanOrEqualTo(majorContourHalfWidth),
      );
    });

    test('keeps its width across zero-length segments (a stationary stop)', () {
      // Three samples at the same east/north, then a move east. The stop
      // has no tangent of its own and must borrow the side vector instead
      // of collapsing both edges onto the centre line.
      final mesh = SpatialPathBuilder.buildRibbon(
        _path([(10, 10, 5), (10, 10, 5.5), (10, 10, 6), (20, 10, 6)]),
        proj,
      );
      const hw = SpatialPathBuilder.ribbonHalfWidth;
      for (var i = 0; i < 4; i++) {
        final vi = i * 6;
        final dx = mesh.positions[vi + 3] - mesh.positions[vi];
        final dz = mesh.positions[vi + 5] - mesh.positions[vi + 2];
        expect(dx, closeTo(0, 1e-6), reason: 'point $i');
        expect(dz.abs(), closeTo(2 * hw, 1e-6), reason: 'point $i');
      }
    });

    test('a path that never moves still has a ribbon of full width', () {
      final mesh = SpatialPathBuilder.buildRibbon(
        _path([(0, 0, 5), (0, 0, 6)]),
        proj,
      );
      const hw = SpatialPathBuilder.ribbonHalfWidth;
      final dx = mesh.positions[3] - mesh.positions[0];
      final dz = mesh.positions[5] - mesh.positions[2];
      expect(math.sqrt(dx * dx + dz * dz), closeTo(2 * hw, 1e-6));
    });

    test('extrudes each point by ribbonHalfWidth to either side, '
        'perpendicular to the horizontal direction of travel', () {
      final mesh = SpatialPathBuilder.buildRibbon(
        _path([(0, 0, 5), (10, 10, 5), (20, 10, 8)]),
        proj,
      );
      const hw = SpatialPathBuilder.ribbonHalfWidth;
      final xs = [proj.xOf(0), proj.xOf(10), proj.xOf(20)];
      final zs = [proj.zOf(0), proj.zOf(10), proj.zOf(10)];

      expect(mesh.positions, hasLength(3 * 6));
      expect(mesh.indices, hasLength(2 * 6));
      for (var i = 0; i < 3; i++) {
        final vi = i * 6;
        final dx = mesh.positions[vi + 3] - mesh.positions[vi];
        final dz = mesh.positions[vi + 5] - mesh.positions[vi + 2];
        expect(math.sqrt(dx * dx + dz * dz), closeTo(2 * hw, 1e-6));
        // Centered on the projected point.
        expect(
          (mesh.positions[vi] + mesh.positions[vi + 3]) / 2,
          closeTo(xs[i], 1e-6),
        );
        expect(
          (mesh.positions[vi + 2] + mesh.positions[vi + 5]) / 2,
          closeTo(zs[i], 1e-6),
        );
        // Perpendicular to the forward difference (last point reuses the
        // previous segment).
        final j = i < 2 ? i : i - 1;
        final tx = xs[j + 1] - xs[j];
        final tz = zs[j + 1] - zs[j];
        expect(dx * tx + dz * tz, closeTo(0, 1e-6));
      }
    });

    test(
      'keeps both edges at the projected depth: width is horizontal only',
      () {
        final mesh = SpatialPathBuilder.buildRibbon(
          _path([(0, 0, 5), (10, 0, 12)]),
          proj,
        );
        expect(mesh.positions[1], closeTo(proj.yOf(5), 1e-9));
        expect(mesh.positions[4], closeTo(proj.yOf(5), 1e-9));
        expect(mesh.positions[7], closeTo(proj.yOf(12), 1e-9));
        expect(mesh.positions[10], closeTo(proj.yOf(12), 1e-9));
      },
    );

    test('returns an empty mesh for fewer than two points', () {
      final mesh = SpatialPathBuilder.buildRibbon(_path([(0, 0, 5)]), proj);
      expect(mesh.positions, isEmpty);
      expect(mesh.indices, isEmpty);
      expect(mesh.colors, isEmpty);
    });
  });
}
