import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_scene_geometry_service.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_z_axis_input.dart';

void main() {
  const service = NavTrackSceneGeometryService();

  group('NavTrackSceneGeometryService.build', () {
    test('bounds reflect the input duration and max depth', () {
      const data = NavTrack3dSceneData(
        times: [0, 10, 20],
        depths: [0, 5, 10],
        temperatures: [null, null, null],
        speeds: [null, null, null],
        batteryVolts: [null, null, null],
        durationSeconds: 20,
        maxDepthMeters: 10,
      );
      final scene = service.build(data, TrackSceneMetric.depth);
      expect(scene.bounds.durationSeconds, 20);
      expect(scene.bounds.maxDepthMeters, 10);
    });

    test('produces a non-empty ribbon for a 2+ point input', () {
      const data = NavTrack3dSceneData(
        times: [0, 10, 20],
        depths: [0, 5, 10],
        temperatures: [null, null, null],
        speeds: [1.0, 1.2, 0.9],
        batteryVolts: [null, null, null],
        durationSeconds: 20,
        maxDepthMeters: 10,
      );
      final scene = service.build(data, TrackSceneMetric.speed);
      expect(scene.layers, hasLength(2));
      for (final layer in scene.layers) {
        expect(layer.mesh.positions, isNotEmpty);
      }
      expect(scene.markers, isEmpty);
      expect(scene.scrubPath, isNotNull);
    });

    test('an empty input returns a scene with empty layers, not a throw', () {
      const data = NavTrack3dSceneData(
        times: [],
        depths: [],
        temperatures: [],
        speeds: [],
        batteryVolts: [],
        durationSeconds: 0,
        maxDepthMeters: 0,
      );
      final scene = service.build(data, TrackSceneMetric.depth);
      for (final layer in scene.layers) {
        expect(layer.mesh.positions, isEmpty);
      }
    });

    test('zs stay flat at 0 everywhere when no Z axis is picked', () {
      const data = NavTrack3dSceneData(
        times: [0, 10],
        depths: [0, 5],
        temperatures: [10.0, 12.0],
        speeds: [null, null],
        batteryVolts: [null, null],
        durationSeconds: 10,
        maxDepthMeters: 5,
      );
      final scene = service.build(data, TrackSceneMetric.temperature);
      expect(scene.scrubPath!.zs, [0, 0]);
    });

    test('a Z axis moves samples off the flat plane', () {
      const data = NavTrack3dSceneData(
        times: [0, 10, 20],
        depths: [0, 5, 10],
        temperatures: [10.0, 15.0, 20.0],
        speeds: [null, null, null],
        batteryVolts: [null, null, null],
        durationSeconds: 20,
        maxDepthMeters: 10,
      );
      final zAxis = TrackZAxisInput(
        spec: ZAxisSpec.fromRange(min: 10, max: 20, symbol: '°C'),
        values: data.temperatures,
      );
      final scene = service.build(data, TrackSceneMetric.depth, zAxis: zAxis);
      final zs = scene.scrubPath!.zs!;
      expect(zs, isNot(everyElement(0)));
      // Rising temperature should move samples monotonically along Z.
      expect(zs[0], lessThan(zs[1]));
      expect(zs[1], lessThan(zs[2]));
    });

    test('a Z axis with fewer than two finite samples leaves zs flat', () {
      const data = NavTrack3dSceneData(
        times: [0, 10],
        depths: [0, 5],
        temperatures: [10.0, null],
        speeds: [null, null],
        batteryVolts: [null, null],
        durationSeconds: 10,
        maxDepthMeters: 5,
      );
      final zAxis = TrackZAxisInput(
        spec: ZAxisSpec.fromRange(min: 10, max: 10, symbol: '°C'),
        values: data.temperatures,
      );
      final scene = service.build(data, TrackSceneMetric.depth, zAxis: zAxis);
      expect(scene.scrubPath!.zs, [0, 0]);
    });
  });
}
