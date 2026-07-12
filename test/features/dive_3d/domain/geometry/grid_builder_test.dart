import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/grid_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

void main() {
  test('emits one line quad per depth step within max depth', () {
    const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 35);
    final mesh = GridBuilder.build(bounds: bounds, stepMeters: 10)!;
    // Steps at 10, 20, 30 -> 3 quads
    expect(mesh.vertexCount, 12);
    expect(mesh.triangleCount, 6);
    // First line at 10m -> y = -(10/35)*6
    expect(mesh.positions[1], closeTo(-(10 / 35) * 6 - 0.015, 1e-4));
    expect(mesh.positions[4], closeTo(-(10 / 35) * 6 + 0.015, 1e-4));
  });

  test('returns null when the dive is shallower than one step', () {
    const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 8);
    expect(GridBuilder.build(bounds: bounds, stepMeters: 10), isNull);
  });
}
