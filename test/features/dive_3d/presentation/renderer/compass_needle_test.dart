import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

SceneProjector projector({required double yaw, required double pitch}) =>
    SceneProjector(
      size: const Size(800, 600),
      bounds: const SceneBounds(durationSeconds: 1, maxDepthMeters: 30),
      yawDegrees: yaw,
      pitchDegrees: pitch,
      zoom: 1,
    );

double _norm(double radians) {
  var r = radians % (2 * math.pi);
  if (r > math.pi) r -= 2 * math.pi;
  if (r < -math.pi) r += 2 * math.pi;
  return r;
}

void main() {
  test('near top-down with no yaw, the needle is vertical on screen', () {
    // In this engine's camera convention, positive pitch tips scene-north
    // toward the screen bottom: +Z projects to +pi/2 (canvas y is down).
    // The compass's job is to reflect the projection truthfully, whatever
    // the convention.
    final angle = compassNeedleAngle(projector(yaw: 0, pitch: 80));
    expect(angle, isNotNull);
    expect(_norm(angle! - math.pi / 2), closeTo(0, 0.05));
  });

  test('rotating the camera yaw rotates the needle by the same amount', () {
    final a0 = compassNeedleAngle(projector(yaw: 10, pitch: 60))!;
    final a90 = compassNeedleAngle(projector(yaw: 100, pitch: 60))!;
    expect(_norm(a90 - a0).abs(), closeTo(math.pi / 2, 0.05));
  });

  test('viewing straight along north yields no needle', () {
    // yaw 0, pitch 0: +Z runs along the view axis; the projected delta
    // collapses, so the compass must hide rather than point a lie.
    expect(compassNeedleAngle(projector(yaw: 0, pitch: 0)), isNull);
  });
}
