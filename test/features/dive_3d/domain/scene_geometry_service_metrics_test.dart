import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

Dive3dSceneData richSceneData({
  Map<String, List<TankPressurePoint>> tankPressures = const {},
}) => Dive3dSceneData(
  diveId: 'd1',
  times: const [0, 60, 120, 180],
  depths: const [0, 20, 20, 0],
  temperatures: const [22, 18, 16, 21],
  ascentRates: const [0, -10, 0, 11],
  ppO2s: const [0.21, 1.1, 1.2, 0.4],
  cnss: const [0, 5, 8, 9],
  heartRates: const [70, 90, 88, 75],
  ceilings: const [null, 3.0, 3.0, null],
  ttss: const [null, 600, 500, null],
  tankPressures: tankPressures,
  gasSwitches: const [],
  bookmarkEvents: const [],
  photos: const [],
  durationSeconds: 180,
  maxDepthMeters: 20,
);

void main() {
  const service = SceneGeometryService();

  test('builds a colored ribbon for every metric', () {
    final withTank = richSceneData(
      tankPressures: {
        't1': const [
          TankPressurePoint(
            id: 'p1',
            tankId: 't1',
            timestamp: 0,
            pressure: 200,
          ),
          TankPressurePoint(
            id: 'p2',
            tankId: 't1',
            timestamp: 180,
            pressure: 80,
          ),
        ],
      },
    );
    for (final metric in SceneMetric.values) {
      final geometry = service.build(withTank, metric);
      expect(geometry.ribbon.colors.length, geometry.ribbon.vertexCount * 3);
      expect(
        geometry.ribbon.colors.every((c) => c.isFinite),
        isTrue,
        reason: 'metric $metric produced non-finite colors',
      );
    }
  });

  test('ceiling surface is built when ceilings exist', () {
    final geometry = service.build(richSceneData(), SceneMetric.depth);
    expect(geometry.ceilingSurface, isNotNull);
  });

  test('tank pressure metric interpolates between pressure samples', () {
    final data = richSceneData(
      tankPressures: {
        't1': const [
          TankPressurePoint(
            id: 'p1',
            tankId: 't1',
            timestamp: 0,
            pressure: 200,
          ),
          TankPressurePoint(
            id: 'p2',
            tankId: 't1',
            timestamp: 180,
            pressure: 80,
          ),
        ],
      },
    );
    final lookup = ProfileLookupOverPressure(data.tankPressures['t1']!);
    expect(lookup.at(90), closeTo(140.0, 1e-9));
    expect(lookup.at(-10), 200.0);
    expect(lookup.at(999), 80.0);
  });

  test('tank pressure metric with no tanks yields null-colored ribbon', () {
    final geometry = service.build(richSceneData(), SceneMetric.tankPressure);
    // All-null pressures map to the neutral gray (0.62-ish channels).
    expect(geometry.ribbon.colors[0], closeTo(0.62, 0.01));
  });

  test('grid step parameter controls line count', () {
    final coarse = service.build(
      richSceneData(),
      SceneMetric.depth,
      gridStepMeters: 20,
    );
    final fine = service.build(
      richSceneData(),
      SceneMetric.depth,
      gridStepMeters: 5,
    );
    expect(fine.grid!.triangleCount, greaterThan(coarse.grid!.triangleCount));
  });
}
