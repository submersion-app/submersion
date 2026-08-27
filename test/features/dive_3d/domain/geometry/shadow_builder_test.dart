import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/shadow_builder.dart';

void main() {
  const bounds = SceneBounds(
    durationSeconds: 100,
    maxDepthMeters: 30,
    sceneMinZ: -SceneBounds.zPathHalfSpan,
    sceneMaxZ: SceneBounds.zPathHalfSpan,
  );

  test('three wall strips, one per wall, each lifted off its wall', () {
    final s = ShadowBuilder.build(
      times: [0, 50, 100],
      depths: [0, 30, 0],
      zs: [-1, 0, 1],
      bounds: bounds,
    );
    expect(s.walls.vertexCount, 18);
    expect(s.walls.triangleCount, 12);
    final p = s.walls.positions;
    // Back wall pair for sample 1: x = 5, y = -6 +/- half, z = minZ + lift.
    expect(p[6], 5);
    expect(p[7], closeTo(-6 - ShadowBuilder.halfThickness, 1e-6));
    expect(p[8], closeTo(bounds.sceneMinZ + ShadowBuilder.lift, 1e-6));
    // Floor pair for sample 1 lives at vertex 2n + 2 = 8.
    expect(p[8 * 3 + 1], closeTo(bounds.sceneMinY + ShadowBuilder.lift, 1e-6));
    expect(p[8 * 3 + 2], closeTo(0 - ShadowBuilder.halfThickness, 1e-6));
    // Left wall pair for sample 1 lives at vertex 4n + 2 = 14.
    expect(p[14 * 3], closeTo(ShadowBuilder.lift, 1e-6));
    expect(p[14 * 3 + 2], 0);
    expect(s.walls.opacity, 0.45);
  });

  test('drop lines are quads from the path to the floor, about 24 of them', () {
    const n = 240;
    final times = [for (var i = 0; i < n; i++) i * 100 / (n - 1)];
    final s = ShadowBuilder.build(
      times: times,
      depths: List.filled(n, 15),
      zs: List.filled(n, 0.5),
      bounds: bounds,
    );
    expect(s.drops.vertexCount, 24 * 4);
    expect(s.drops.triangleCount, 24 * 2);
    // First quad: top pair at y = yOf(15) = -3, bottom pair on the floor.
    expect(s.drops.positions[1], -3);
    expect(s.drops.positions[7], bounds.sceneMinY);
    expect(s.drops.opacity, 0.3);
  });
}
