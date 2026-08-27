import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

void main() {
  final data = Dive3dSceneData(
    diveId: 'd1',
    times: const [0, 60, 120],
    depths: const [0, 18, 0],
    temperatures: const [null, null, null],
    ascentRates: const [null, null, null],
    ppO2s: const [null, null, null],
    cnss: const [null, null, null],
    heartRates: const [null, null, null],
    ceilings: const [null, null, null],
    ttss: const [null, null, null],
    tankPressures: const {},
    gasSwitches: [
      GasSwitchWithTank(
        gasSwitch: GasSwitch(
          id: 'gs1',
          diveId: 'd1',
          timestamp: 60,
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
    durationSeconds: 120,
    maxDepthMeters: 18,
  );
  const bounds = SceneBounds(durationSeconds: 120, maxDepthMeters: 18);

  test('marker Z interpolates the decimated path', () {
    final markers = MarkerLayout.layout(
      data: data,
      bounds: bounds,
      pathTimes: const [0, 120],
      pathZs: const [-2, 2],
    );
    expect(markers.single.z, closeTo(0, 1e-9));
  });

  test('marker Z is 0 without a path', () {
    expect(MarkerLayout.layout(data: data, bounds: bounds).single.z, 0);
  });
}
