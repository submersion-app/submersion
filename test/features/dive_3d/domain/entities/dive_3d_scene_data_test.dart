import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

DiveProfilePoint point(int t, double d, {double? temp, double? ppO2}) =>
    DiveProfilePoint(timestamp: t, depth: d, temperature: temp, ppO2: ppO2);

void main() {
  group('Dive3dSceneData.fromDomain', () {
    test('extracts parallel series from profile points', () {
      final data = Dive3dSceneData.fromDomain(
        diveId: 'd1',
        points: [point(0, 0, temp: 20), point(60, 18, temp: 15)],
        tankPressures: const {},
        gasSwitches: const [],
        events: const [],
        photos: const [],
      );
      expect(data.times, [0.0, 60.0]);
      expect(data.depths, [0.0, 18.0]);
      expect(data.temperatures, [20.0, 15.0]);
      expect(data.durationSeconds, 60);
      expect(data.maxDepthMeters, 18);
      expect(data.hasProfile, isTrue);
    });

    test('hasProfile is false with fewer than two samples', () {
      final data = Dive3dSceneData.fromDomain(
        diveId: 'd1',
        points: [point(0, 0)],
        tankPressures: const {},
        gasSwitches: const [],
        events: const [],
        photos: const [],
      );
      expect(data.hasProfile, isFalse);
    });

    test('availableMetrics reflects present data only', () {
      final data = Dive3dSceneData.fromDomain(
        diveId: 'd1',
        points: [point(0, 0, ppO2: 1.0), point(60, 18, ppO2: 1.2)],
        tankPressures: const {},
        gasSwitches: const [],
        events: const [],
        photos: const [],
      );
      expect(data.availableMetrics, contains(SceneMetric.ppO2));
      expect(data.availableMetrics, contains(SceneMetric.depth));
      expect(data.availableMetrics, isNot(contains(SceneMetric.temperature)));
      expect(data.availableMetrics, isNot(contains(SceneMetric.tankPressure)));
    });
  });
}
