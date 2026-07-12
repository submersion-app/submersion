import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

Dive3dSceneData sceneData({int samples = 100}) {
  final times = [for (var i = 0; i < samples; i++) i.toDouble()];
  final depths = [for (var i = 0; i < samples; i++) 10.0];
  return Dive3dSceneData(
    diveId: 'd1',
    times: times,
    depths: depths,
    temperatures: [for (var i = 0; i < samples; i++) 15.0],
    ascentRates: [for (var i = 0; i < samples; i++) null],
    ppO2s: [for (var i = 0; i < samples; i++) null],
    cnss: [for (var i = 0; i < samples; i++) null],
    heartRates: [for (var i = 0; i < samples; i++) null],
    ceilings: [for (var i = 0; i < samples; i++) null],
    ttss: [for (var i = 0; i < samples; i++) null],
    tankPressures: const {},
    gasSwitches: const [],
    bookmarkEvents: const [],
    photos: const [],
    durationSeconds: (samples - 1).toDouble(),
    maxDepthMeters: 10,
  );
}

SceneLayer? layerFor(Scene3d scene, SceneOverlay overlay) =>
    scene.layers.where((l) => l.overlay == overlay).firstOrNull;

// The ribbon is the last structural (null-overlay) layer.
SceneLayer ribbonLayer(Scene3d scene) =>
    scene.layers.lastWhere((l) => l.overlay == null);

void main() {
  const service = SceneGeometryService();

  test('builds ribbon, curtain and strata layers; skips absent overlays', () {
    final scene = service.build(sceneData(), SceneMetric.depth);
    expect(ribbonLayer(scene).mesh.vertexCount, 200);
    expect(layerFor(scene, SceneOverlay.curtain)!.mesh.vertexCount, 200);
    expect(layerFor(scene, SceneOverlay.strata), isNotNull);
    expect(layerFor(scene, SceneOverlay.ceiling), isNull);
    expect(scene.markers, isEmpty);
    expect(scene.scrubPath, isNotNull);
  });

  test('decimates geometry above 2000 samples', () {
    final scene = service.build(sceneData(samples: 6000), SceneMetric.depth);
    final ribbon = ribbonLayer(scene).mesh;
    expect(ribbon.vertexCount, lessThanOrEqualTo(2 * 2000));
    expect(ribbon.vertexCount, greaterThan(2 * 1000));
  });
}
