import 'dart:typed_data';
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

  test('projectAll fills the buffers exactly as the point methods do', () {
    final projector = SceneProjector(
      size: size,
      bounds: bounds,
      yawDegrees: 41,
      pitchDegrees: 63,
      zoom: 1.7,
    );
    final positions = Float32List.fromList([
      0.5, -3.25, 1.5, //
      7.0, -0.5, -2.0,
      3.3, -8.0, 0.0,
    ]);
    final sortHeights = Float32List.fromList([0, -1, -7.5]);
    // Two slots ahead of the mesh, as for the second mesh in a soup.
    Float32List buf() => Float32List(5);
    final vx = buf(), vy = buf(), vz = buf(), vzSort = buf();
    final sx = buf(), sy = buf();
    projector.projectAll(
      positions,
      3,
      start: 2,
      vx: vx,
      vy: vy,
      vz: vz,
      vzSort: vzSort,
      sx: sx,
      sy: sy,
      sortHeights: sortHeights,
    );
    expect(vx.sublist(0, 2), [0, 0], reason: 'slots before start untouched');
    for (var i = 0; i < 3; i++) {
      final x = positions[i * 3], y = positions[i * 3 + 1];
      final z = positions[i * 3 + 2];
      final v = projector.viewOf(x, y, z);
      final o = projector.projectView(v);
      final w = Float32List.fromList([
        v.$1,
        v.$2,
        v.$3,
        v.$3 + (sortHeights[i] - y) * projector.depthPerUnitY,
        o.dx,
        o.dy,
      ]);
      expect(
        [vx[i + 2], vy[i + 2], vz[i + 2], vzSort[i + 2], sx[i + 2], sy[i + 2]],
        w,
        reason: 'vertex $i',
      );
    }

    // Without sort heights the sort depth is the view depth.
    projector.projectAll(
      positions,
      3,
      start: 0,
      vx: vx,
      vy: vy,
      vz: vz,
      vzSort: vzSort,
      sx: sx,
      sy: sy,
    );
    expect(vzSort.sublist(0, 3), vz.sublist(0, 3));
  });
}
