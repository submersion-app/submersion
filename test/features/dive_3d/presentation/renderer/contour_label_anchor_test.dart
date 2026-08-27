import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

void main() {
  test('bestContourAnchorIndex picks the camera-nearest candidate', () {
    const bounds = SceneBounds(durationSeconds: 1, maxDepthMeters: 30);
    // Default camera (yaw -32, pitch 22). Three candidates along the scene:
    // the one with the largest viewDepth must win; assert against viewDepth
    // itself so the test is camera-convention-proof.
    final p = SceneProjector(size: const Size(400, 300), bounds: bounds);
    final anchors = <double>[
      2, -1, -2, // triplet 0
      5, -1, 0, // triplet 1
      8, -1, 2, // triplet 2
    ];
    final best = bestContourAnchorIndex(p, anchors);
    final depths = [
      p.viewDepth(2, -1, -2),
      p.viewDepth(5, -1, 0),
      p.viewDepth(8, -1, 2),
    ];
    final maxDepth = depths.reduce((a, b) => a > b ? a : b);
    expect(depths[best], maxDepth);
  });
}
