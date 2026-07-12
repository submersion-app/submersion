import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/career/career_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/career/career_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

CareerDiveInput dive(int index, {double maxDepth = 20, int minutes = 30}) {
  final times = [for (var m = 0; m <= minutes; m++) (m * 60).toDouble()];
  final depths = [for (var m = 0; m <= minutes; m++) maxDepth];
  return CareerDiveInput(
    index: index,
    date: DateTime.utc(2026, 1, 1).add(Duration(days: index)),
    maxDepthMeters: maxDepth,
    times: times,
    depths: depths,
  );
}

void main() {
  const service = CareerGeometryService();

  test('builds one ribbon layer per dive at distinct Z', () {
    final scene = service.build(
      CareerSceneData(dives: [dive(0), dive(1), dive(2)]),
    );
    expect(scene.layers.length, 3);
    // Each ribbon's leading vertex z differs (stacked along Z).
    double zOf(int layer) => scene.layers[layer].mesh.positions[2];
    expect(zOf(0), lessThan(zOf(1)));
    expect(zOf(1), lessThan(zOf(2)));
    // The stack is symmetric about z=0.
    expect(scene.bounds.sceneMinZ, closeTo(-scene.bounds.sceneMaxZ, 1e-9));
  });

  test('Z range widens with more dives', () {
    final wide = service.build(
      CareerSceneData(dives: [for (var i = 0; i < 8; i++) dive(i)]),
    );
    // 8 dives at gap 0.6 span well beyond the default +/-1 slab.
    expect(wide.bounds.sceneMinZ, lessThan(-1.0));
    expect(wide.bounds.sceneMaxZ, greaterThan(1.0));
  });

  test('shares one time and depth scale across the set', () {
    final scene = service.build(
      CareerSceneData(dives: [dive(0, minutes: 20), dive(1, minutes: 60)]),
    );
    // Max duration = 60 min. The 60-min dive should span the full X width;
    // the 20-min dive should end at ~1/3.
    final longRibbon = scene.layers[1].mesh;
    final shortRibbon = scene.layers[0].mesh;
    double lastX(m) => m.positions[(m.vertexCount - 2) * 3];
    expect(lastX(longRibbon), greaterThan(lastX(shortRibbon) * 2.5));
  });

  test('recency vs depth coloring differ', () {
    final data = CareerSceneData(
      dives: [dive(0, maxDepth: 10), dive(1, maxDepth: 40)],
    );
    final recency = service.build(data, colorMode: CareerColorMode.recency);
    final depth = service.build(data, colorMode: CareerColorMode.depth);
    // Deepest dive is colored differently between the two modes.
    expect(
      recency.layers[1].mesh.colors[0],
      isNot(closeTo(depth.layers[1].mesh.colors[0], 1e-6)),
    );
  });

  test('empty set yields an empty scene', () {
    final scene = service.build(const CareerSceneData(dives: []));
    expect(scene.layers, isEmpty);
  });

  test('single dive centers at z=0 without a widened range', () {
    final scene = service.build(CareerSceneData(dives: [dive(0)]));
    expect(
      scene.layers.single.mesh.positions[2],
      closeTo(-SceneBounds.zHalfWidth, 1e-6),
    );
  });

  test('career scene has no scrub path (static, no timeline)', () {
    final scene = service.build(CareerSceneData(dives: [dive(0), dive(1)]));
    expect(scene.scrubPath, isNull);
  });
}
