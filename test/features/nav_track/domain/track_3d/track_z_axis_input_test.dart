import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_z_axis_input.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const data = NavTrack3dSceneData(
    times: [0, 10, 20],
    depths: [0, 5, 10],
    temperatures: [10, null, 20],
    speeds: [1.0, 1.2, 0.9],
    batteryVolts: [null, null, null],
    durationSeconds: 20,
    maxDepthMeters: 10,
  );

  test('fits a nice range around the finite samples, filling nulls by '
      'interpolation when resampled -- here just the raw series is '
      'returned', () {
    final input = buildTrackZAxisInput(
      data,
      TrackSceneMetric.temperature,
      const UnitFormatter(AppSettings()),
    );
    expect(input, isNotNull);
    expect(input!.spec.lo, lessThanOrEqualTo(10));
    expect(input.spec.hi, greaterThanOrEqualTo(20));
    expect(input.values, [10, null, 20]);
  });

  test('converts speed to the diver-s unit, m/min by default', () {
    final input = buildTrackZAxisInput(
      data,
      TrackSceneMetric.speed,
      const UnitFormatter(AppSettings()),
    );
    expect(input, isNotNull);
    // 1.0 m/s -> 60 m/min, 1.2 m/s -> 72 m/min, 0.9 m/s -> 54 m/min.
    expect(input!.values, [60.0, 72.0, 54.0]);
    expect(input.spec.symbol, 'm/min');
  });

  test('converts speed to ft/min in imperial', () {
    final input = buildTrackZAxisInput(
      data,
      TrackSceneMetric.speed,
      const UnitFormatter(AppSettings(depthUnit: DepthUnit.feet)),
    );
    expect(input!.spec.symbol, 'ft/min');
  });

  test('returns null when fewer than two finite samples exist', () {
    const empty = NavTrack3dSceneData(
      times: [0, 10],
      depths: [0, 5],
      temperatures: [null, null],
      speeds: [null, null],
      batteryVolts: [null, null],
      durationSeconds: 10,
      maxDepthMeters: 5,
    );
    final input = buildTrackZAxisInput(
      empty,
      TrackSceneMetric.temperature,
      const UnitFormatter(AppSettings()),
    );
    expect(input, isNull);
  });

  test('depth is a valid Z candidate too, in the diver-s depth unit', () {
    final input = buildTrackZAxisInput(
      data,
      TrackSceneMetric.depth,
      const UnitFormatter(AppSettings()),
    );
    expect(input, isNotNull);
    expect(input!.values, [0, 5, 10]);
    expect(input.spec.symbol, 'm');
  });

  test('converts depth to feet in imperial', () {
    final input = buildTrackZAxisInput(
      data,
      TrackSceneMetric.depth,
      const UnitFormatter(AppSettings(depthUnit: DepthUnit.feet)),
    );
    expect(input!.spec.symbol, 'ft');
  });
}
