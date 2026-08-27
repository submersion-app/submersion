import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ceiling_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

void main() {
  const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 30);

  test('returns null when no ceiling exists', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 50.0],
      depths: [10.0, 12.0],
      zs: [0, 0],
      ceilings: [null, 0.0],
      bounds: bounds,
    );
    expect(mesh, isNull);
  });

  test('builds a sheet from the path up to the ceiling at the path Z', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 50.0, 100.0],
      depths: [20.0, 20.0, 20.0],
      zs: [0.5, 0.5, -0.5],
      ceilings: [null, 6.0, 3.0],
      bounds: bounds,
    )!;
    expect(mesh.vertexCount, 4); // 2 ceiling samples x 2 verts
    expect(mesh.triangleCount, 2);
    // Sample at t=50: bottom vertex on the path (depth 20 -> y = -4),
    // top vertex at the ceiling (6 m -> y = -1.2), both at z = 0.5.
    final want = [5, -4, 0.5, 5, -1.2, 0.5];
    for (var k = 0; k < want.length; k++) {
      expect(mesh.positions[k], closeTo(want[k], 1e-6));
    }
    // Sample at t=100 sits at z = -0.5.
    expect(mesh.positions[8], closeTo(-0.5, 1e-6));
  });

  test('violation samples (depth shallower than ceiling) are red', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 10.0],
      depths: [10.0, 4.0], // second sample above 6m ceiling
      zs: [0, 0],
      ceilings: [6.0, 6.0],
      bounds: bounds,
    )!;
    expect(mesh.colors[1], greaterThan(0.4)); // amber g channel
    expect(mesh.colors[7], lessThan(0.4)); // violation g channel
  });

  test('separate deco periods are not bridged', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 10.0, 20.0, 30.0],
      depths: [20.0, 20.0, 20.0, 20.0],
      zs: [0, 0, 0, 0],
      ceilings: [6.0, null, 6.0, 6.0],
      bounds: bounds,
    )!;
    expect(mesh.vertexCount, 6);
    expect(mesh.triangleCount, 2); // only the 20-30 s run forms a quad
  });
}
