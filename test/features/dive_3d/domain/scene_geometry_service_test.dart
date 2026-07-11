import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';

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

void main() {
  const service = SceneGeometryService();

  test('builds ribbon, curtain and strata; skips absent overlays', () {
    final geometry = service.build(sceneData(), SceneMetric.depth);
    expect(geometry.ribbon.vertexCount, 200);
    expect(geometry.curtain.vertexCount, 200);
    expect(geometry.strata, isNotNull);
    expect(geometry.ceilingSurface, isNull);
    expect(geometry.markers, isEmpty);
  });

  test('decimates geometry above 2000 samples', () {
    final geometry = service.build(
      sceneData(samples: 6000),
      SceneMetric.depth,
    );
    expect(geometry.ribbon.vertexCount, lessThanOrEqualTo(2 * 2000));
    expect(geometry.ribbon.vertexCount, greaterThan(2 * 1000));
  });
}
