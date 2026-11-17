import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// An Avelo Hydrotank's pressure rises with the water pumped in for buoyancy,
/// so it is no measure of the gas used (issue #4657): no cylinder SAC and no
/// segment SAC from it, while a pony beside it keeps its own.
void main() {
  const service = GasAnalysisService();

  // A flat 12 m dive, one sample every 10 s for 45 minutes.
  final profile = [
    for (var t = 0; t <= 2700; t += 10)
      DiveProfilePoint(timestamp: t, depth: 12.0),
  ];

  Dive dive(List<DiveTank> tanks) => Dive(
    id: 'dive-1',
    dateTime: DateTime(2026, 11, 17, 9),
    runtime: const Duration(minutes: 45),
    avgDepth: 12.0,
    tanks: tanks,
    profile: profile,
  );

  const hydrotank = DiveTank(
    id: 'hydro',
    volume: 10,
    startPressure: 200,
    endPressure: 185,
    gasMix: GasMix(o2: 21),
    role: TankRole.hydrotank,
  );
  const pony = DiveTank(
    id: 'pony',
    volume: 3,
    startPressure: 200,
    endPressure: 170,
    gasMix: GasMix(o2: 21),
    role: TankRole.pony,
    usageDuration: Duration(minutes: 10),
  );

  test('no cylinder SAC row for the Hydrotank; the pony keeps its own', () {
    final rows = service.calculateCylinderSac(
      dive: dive(const [hydrotank, pony]),
      profile: profile,
    );

    expect(rows.map((r) => r.tankId), ['pony']);
    expect(rows.single.sacRate, isNotNull);
  });

  test('a Hydrotank-only dive has no cylinder SAC at all', () {
    final rows = service.calculateCylinderSac(
      dive: dive(const [hydrotank]),
      profile: profile,
    );

    expect(rows, isEmpty);
  });

  test('no phase segment takes a SAC from the Hydrotank', () {
    final segments = service.calculatePhaseSegments(
      profile: profile,
      tanks: const [hydrotank],
      gasSwitches: const [],
    );

    // A segment exists only with a SAC, so there is none.
    expect(segments ?? const [], isEmpty);
  });

  test('no estimated pressure curve for a Hydrotank logged by hand', () {
    // A flat-drop-flat estimate would draw steady gas use the Hydrotank's
    // pressure never measured.
    final estimated = synthesizeEstimatedTankPressures(
      existing: const {},
      tanks: const [hydrotank, pony],
      gasSwitches: const [],
      diveDurationSeconds: 2700,
    );

    expect(estimated.pressures.keys, isNot(contains('hydro')));
  });
}
