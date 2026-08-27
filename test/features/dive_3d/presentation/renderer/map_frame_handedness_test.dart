import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

/// A map-frame scene (terrain, seascape) must never render mirrored: the
/// seafloor a diver sees in 3D has to be the same seafloor the 2D chart
/// shows, not its reflection. Regression guard for issue #1093, where the
/// free-orbit camera flipped north/south while chart mode did not.
void main() {
  final projection = SpatialProjection(
    minEast: -4000,
    maxEast: 4000,
    minNorth: -4000,
    maxNorth: 4000,
    maxDepth: 140,
  );

  final bounds = SceneBounds(
    durationSeconds: 1,
    maxDepthMeters: 140,
    sceneMinY: -SceneBounds.ySpan,
    sceneMaxY: 0.6,
    sceneMinZ: -projection.zHalfExtent,
    sceneMaxZ: projection.zHalfExtent,
  );

  /// Signed area of the (east, north) basis as it lands on the canvas.
  /// Screen y grows DOWNWARD, so an unmirrored map (east anywhere to the
  /// right of north's counter-clockwise side) always yields a NEGATIVE
  /// cross product. A positive one means the world came out reflected.
  double screenCross(SceneProjector p) {
    Offset at(double east, double north) =>
        p.project(projection.xOf(east), 0, projection.zOf(north));
    final origin = at(0, 0);
    final east = at(1000, 0) - origin;
    final north = at(0, 1000) - origin;
    return east.dx * north.dy - east.dy * north.dx;
  }

  SceneProjector poseAt(double yaw, double pitch) => SceneProjector(
    size: const Size(600, 600),
    bounds: bounds,
    yawDegrees: yaw,
    pitchDegrees: pitch,
  );

  test('every orbit pose renders the map frame unmirrored', () {
    for (final yaw in const [-180.0, -110.0, -32.0, 0.0, 47.0, 180.0]) {
      for (final pitch in const [5.0, 22.0, 45.0, 80.0]) {
        expect(
          screenCross(poseAt(yaw, pitch)),
          lessThan(0),
          reason: 'mirrored at yaw $yaw, pitch $pitch',
        );
      }
    }
  });

  test('the default orbit pose renders the map frame unmirrored', () {
    // The pose Dive3dInteractiveViewport opens on.
    expect(screenCross(poseAt(-32, 22)), lessThan(0));
  });

  test('chart pose is a plan view: east right, north up', () {
    final p = poseAt(chartYawDegrees, chartPitchDegrees);
    Offset at(double east, double north) =>
        p.project(projection.xOf(east), 0, projection.zOf(north));
    final origin = at(0, 0);
    final east = at(1000, 0);
    final north = at(0, 1000);
    expect(east.dx, greaterThan(origin.dx));
    expect((east.dy - origin.dy).abs(), lessThan(1e-6));
    expect(north.dy, lessThan(origin.dy)); // screen y grows downward
    expect((north.dx - origin.dx).abs(), lessThan(1e-6));
  });

  test('chart pose looks down from above, not up from below', () {
    final p = poseAt(chartYawDegrees, chartPitchDegrees);
    final surface = p.viewDepth(SceneBounds.xSpan / 2, 0, 0);
    final seabed = p.viewDepth(SceneBounds.xSpan / 2, -SceneBounds.ySpan, 0);
    expect(surface, greaterThan(seabed));
  });

  test(
    'the compass needle points at true north, straight up in chart pose',
    () {
      final p = poseAt(chartYawDegrees, chartPitchDegrees);
      final angle = compassNeedleAngle(p);
      expect(angle, isNotNull);
      // Canvas angles: -pi/2 is straight up.
      expect(angle!, closeTo(-math.pi / 2, 1e-6));

      // And it agrees with where the map frame actually puts north.
      final needle = Offset.fromDirection(angle);
      final north =
          p.project(projection.xOf(0), 0, projection.zOf(1000)) -
          p.project(projection.xOf(0), 0, projection.zOf(0));
      expect(needle.dx * north.dx + needle.dy * north.dy, greaterThan(0));
    },
  );

  test('the orbit compass needle tracks north at every pose it shows', () {
    for (final yaw in const [-110.0, -32.0, 0.0, 47.0]) {
      for (final pitch in const [5.0, 22.0, 45.0, 80.0]) {
        final p = poseAt(yaw, pitch);
        final angle = compassNeedleAngle(p);
        if (angle == null) continue; // degenerate: the rose hides
        final needle = Offset.fromDirection(angle);
        final north =
            p.project(projection.xOf(0), 0, projection.zOf(1000)) -
            p.project(projection.xOf(0), 0, projection.zOf(0));
        expect(
          needle.dx * north.dx + needle.dy * north.dy,
          greaterThan(0),
          reason: 'needle points away from north at yaw $yaw, pitch $pitch',
        );
      }
    }
  });
}
