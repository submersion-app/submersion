import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';

Dive3dSceneData data({
  List<double?> temperatures = const [null, null, null],
  List<int?> ttss = const [null, null, null],
}) => Dive3dSceneData(
  diveId: 'd1',
  times: const [0, 60, 120],
  depths: const [0, 10, 0],
  temperatures: temperatures,
  ascentRates: const [null, null, null],
  ppO2s: const [null, null, null],
  cnss: const [null, null, null],
  heartRates: const [null, null, null],
  ceilings: const [null, null, null],
  ttss: ttss,
  tankPressures: const {},
  gasSwitches: const [],
  bookmarkEvents: const [],
  photos: const [],
  durationSeconds: 120,
  maxDepthMeters: 10,
);

void main() {
  test('zAxisMetrics never offers depth and needs two finite samples', () {
    expect(data().zAxisMetrics, isEmpty);
    expect(data(temperatures: [20, null, null]).zAxisMetrics, isEmpty);
    expect(data(temperatures: [20, 18, null]).zAxisMetrics, {
      SceneMetric.temperature,
    });
  });

  test('tts counts as an available and Z-capable metric', () {
    final d = data(ttss: [null, 600, 300]);
    expect(d.availableMetrics, contains(SceneMetric.tts));
    expect(d.zAxisMetrics, {SceneMetric.tts});
  });
}
