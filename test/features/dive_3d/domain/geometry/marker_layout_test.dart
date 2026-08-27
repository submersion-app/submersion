import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

void main() {
  test('gas switches are anchored above the interpolated ribbon depth', () {
    final data = Dive3dSceneData(
      diveId: 'd1',
      times: const [0, 100],
      depths: const [0, 20],
      temperatures: const [null, null],
      ascentRates: const [null, null],
      ppO2s: const [null, null],
      cnss: const [null, null],
      heartRates: const [null, null],
      ceilings: const [null, null],
      ttss: const [null, null],
      tankPressures: const {},
      gasSwitches: [
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'gs1',
            diveId: 'd1',
            timestamp: 50,
            tankId: 't1',
            createdAt: DateTime.utc(2026),
          ),
          tankName: 'EAN50',
          gasMix: 'EAN50',
          o2Fraction: 0.5,
        ),
      ],
      bookmarkEvents: const [],
      photos: const [],
      durationSeconds: 100,
      maxDepthMeters: 20,
    );
    const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 20);
    final markers = MarkerLayout.layout(data: data, bounds: bounds);
    expect(markers.length, 1);
    expect(markers.first.kind, SceneMarkerKind.gasSwitch);
    expect(markers.first.label, 'EAN50');
    expect(markers.first.x, closeTo(5.0, 1e-9)); // t=50 -> mid x
    // depth at t=50 interpolates to 10m -> y=-3, marker floats +0.4
    expect(markers.first.y, closeTo(-2.6, 1e-9));
  });
}
