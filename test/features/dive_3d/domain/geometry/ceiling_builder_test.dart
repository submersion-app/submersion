import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ceiling_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

void main() {
  const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 30);

  test('returns null when no ceiling exists', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 50.0],
      depths: [10.0, 12.0],
      ceilings: [null, 0.0],
      bounds: bounds,
    );
    expect(mesh, isNull);
  });

  test('builds a strip over the ceiling run at ceiling depth', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 50.0, 100.0],
      depths: [20.0, 20.0, 20.0],
      ceilings: [null, 6.0, 3.0],
      bounds: bounds,
    )!;
    expect(mesh.vertexCount, 4); // 2 ceiling samples x 2 verts
    expect(mesh.triangleCount, 2);
    // Sample at t=50, ceiling 6m -> y = -(6/30)*6 = -1.2
    expect(mesh.positions[1], closeTo(-1.2, 1e-6));
  });

  test('violation samples (depth shallower than ceiling) are red', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 10.0],
      depths: [10.0, 4.0], // second sample above 6m ceiling
      ceilings: [6.0, 6.0],
      bounds: bounds,
    )!;
    // First pair amber-ish (g high), second pair red (g low)
    expect(mesh.colors[1], greaterThan(0.4)); // amber g channel
    expect(mesh.colors[7], lessThan(0.4)); // violation g channel
  });
}
