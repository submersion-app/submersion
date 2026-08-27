import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

Dive3dSceneData data() => const Dive3dSceneData(
  diveId: 'd1',
  times: [0, 60, 120, 180],
  depths: [0, 20, 20, 0],
  temperatures: [22, null, 16, 21],
  ascentRates: [null, null, null, null],
  ppO2s: [null, null, null, null],
  cnss: [null, null, null, null],
  heartRates: [null, null, null, null],
  ceilings: [null, 3.0, 3.0, null],
  ttss: [null, null, null, null],
  tankPressures: {},
  gasSwitches: [],
  bookmarkEvents: [],
  photos: [],
  durationSeconds: 180,
  maxDepthMeters: 20,
);

List<SceneLayer> layersFor(Scene3d s, SceneOverlay o) =>
    s.layers.where((l) => l.overlay == o).toList();

void main() {
  const service = SceneGeometryService();
  const spec = ZAxisSpec(lo: 10, hi: 25, step: 5, symbol: '°C');

  test('None: flat path at z = 0, no shadows, same widened box', () {
    final scene = service.build(data(), SceneMetric.depth);
    expect(scene.scrubPath!.zs, [0, 0, 0, 0]);
    expect(layersFor(scene, SceneOverlay.shadows), isEmpty);
    expect(scene.bounds.sceneMinZ, -SceneBounds.zPathHalfSpan);
    expect(scene.bounds.sceneMaxZ, SceneBounds.zPathHalfSpan);
    expect(scene.layers.last.overlay, isNull); // the path is last
    expect(scene.layers.last.mesh.vertexCount, 16); // tube: 4 per sample
  });

  test('metric on Z: path Z follows the spec, shadows present, gap filled', () {
    final scene = service.build(
      data(),
      SceneMetric.depth,
      zAxis: ZAxisInput(
        metric: SceneMetric.temperature,
        spec: spec,
        values: data().temperatures,
      ),
    );
    final zs = scene.scrubPath!.zs!;
    expect(zs[0], closeTo(spec.zOf(22), 1e-6));
    expect(zs[1], closeTo(spec.zOf(19), 1e-6)); // interpolated 22 -> 16
    expect(zs[2], closeTo(spec.zOf(16), 1e-6));
    expect(layersFor(scene, SceneOverlay.shadows), hasLength(2));
    // Ceiling sheet and curtain ride the same Z as the path.
    final ceiling = layersFor(scene, SceneOverlay.ceiling).single.mesh;
    expect(ceiling.positions[2], closeTo(zs[1], 1e-6));
    final curtain = layersFor(scene, SceneOverlay.curtain).single.mesh;
    expect(curtain.positions[2], closeTo(zs[0], 1e-6));
  });

  test('a Z series with fewer than two finite samples falls back to None', () {
    final scene = service.build(
      data(),
      SceneMetric.depth,
      zAxis: const ZAxisInput(
        metric: SceneMetric.temperature,
        spec: spec,
        values: [22, null, null, null],
      ),
    );
    expect(scene.scrubPath!.zs, [0, 0, 0, 0]);
    expect(layersFor(scene, SceneOverlay.shadows), isEmpty);
  });
}
