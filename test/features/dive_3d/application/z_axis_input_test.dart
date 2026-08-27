import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/application/z_axis_input.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

Dive3dSceneData data({Map<String, List<TankPressurePoint>> tanks = const {}}) =>
    Dive3dSceneData(
      diveId: 'd1',
      times: const [0, 60, 120],
      depths: const [0, 20, 0],
      temperatures: const [22, 12, null],
      ascentRates: const [null, null, null],
      ppO2s: const [null, null, null],
      cnss: const [null, null, null],
      heartRates: const [null, null, null],
      ceilings: const [null, null, null],
      ttss: const [null, 600, 300],
      tankPressures: tanks,
      gasSwitches: const [],
      bookmarkEvents: const [],
      photos: const [],
      durationSeconds: 120,
      maxDepthMeters: 20,
    );

void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      temperatureUnit: TemperatureUnit.fahrenheit,
      pressureUnit: PressureUnit.psi,
    ),
  );

  test('temperature converts to the display unit and gets a nice range', () {
    final c = buildZAxisInput(data(), SceneMetric.temperature, metric)!;
    expect(c.values, [22, 12, null]);
    expect(
      (c.spec.lo, c.spec.hi, c.spec.step, c.spec.symbol),
      (10.0, 25.0, 5.0, '°C'),
    );
    final f = buildZAxisInput(data(), SceneMetric.temperature, imperial)!;
    expect(f.values[0], closeTo(71.6, 1e-9));
    expect(f.spec.symbol, '°F');
    expect((f.spec.lo, f.spec.hi), (50.0, 75.0));
  });

  test('tts is minutes; tank pressure resamples the first tank', () {
    final tts = buildZAxisInput(data(), SceneMetric.tts, metric)!;
    expect(tts.values, [null, 10, 5]);
    expect(tts.spec.symbol, 'min');
    final tanks = {
      't1': const [
        TankPressurePoint(id: 'p1', tankId: 't1', timestamp: 0, pressure: 200),
        TankPressurePoint(
          id: 'p2',
          tankId: 't1',
          timestamp: 120,
          pressure: 100,
        ),
      ],
    };
    final bar = buildZAxisInput(
      data(tanks: tanks),
      SceneMetric.tankPressure,
      metric,
    )!;
    expect(bar.values[1], closeTo(150, 1e-9));
    expect(bar.spec.symbol, 'bar');
    final psi = buildZAxisInput(
      data(tanks: tanks),
      SceneMetric.tankPressure,
      imperial,
    )!;
    expect(psi.values[0], closeTo(2900.75, 0.1));
    expect(psi.spec.symbol, 'psi');
  });

  test('too few samples yields null; depth is rejected', () {
    expect(buildZAxisInput(data(), SceneMetric.ppO2, metric), isNull);
    expect(
      () => buildZAxisInput(data(), SceneMetric.depth, metric),
      throwsArgumentError,
    );
  });
}
