import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';

void main() {
  const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 10);
  const size = Size(400, 300);

  test('projected scene fits inside the canvas', () {
    final projector = SceneProjector(size: size, bounds: bounds);
    final corners = [
      [0.0, 0.0, -1.0],
      [SceneBounds.xSpan, 0.0, 1.0],
      [0.0, -SceneBounds.ySpan, -1.0],
      [SceneBounds.xSpan, -SceneBounds.ySpan, 1.0],
    ];
    for (final c in corners) {
      final p = projector.project(c[0], c[1], c[2]);
      expect(p.dx, inInclusiveRange(0, size.width));
      expect(p.dy, inInclusiveRange(0, size.height));
    }
  });

  test('deeper scene points project lower on screen', () {
    final projector = SceneProjector(size: size, bounds: bounds);
    final surface = projector.project(5, 0, 0);
    final deep = projector.project(5, -SceneBounds.ySpan, 0);
    expect(deep.dy, greaterThan(surface.dy));
  });

  test('viewDepth distinguishes points after yaw rotation', () {
    final projector = SceneProjector(size: size, bounds: bounds);
    final near = projector.viewDepth(SceneBounds.xSpan, -3, 0);
    final far = projector.viewDepth(0, -3, 0);
    expect(near, isNot(equals(far)));
  });

  test('projection is deterministic', () {
    final a = SceneProjector(size: size, bounds: bounds).project(3, -2, 0.1);
    final b = SceneProjector(size: size, bounds: bounds).project(3, -2, 0.1);
    expect(a, b);
  });
}
