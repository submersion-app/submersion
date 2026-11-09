import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #2930: minutes the diver entered for breathing a cylinder at the
/// surface after the computer stopped logging count at 0 m, since the logged
/// end pressure includes that gas.
void main() {
  // 100 bar of an unsized cylinder over 40 minutes at 18 m, plus 10 minutes
  // on the surface.
  const tank = DiveTank(
    id: 't',
    startPressure: 200,
    endPressure: 100,
    surfaceBreathingDuration: Duration(minutes: 10),
  );

  Dive dive({
    List<DiveTank> tanks = const [tank],
    List<DiveProfilePoint> profile = const [],
  }) => Dive(
    id: 'd',
    dateTime: DateTime.utc(2026, 1, 1),
    runtime: const Duration(minutes: 40),
    avgDepth: 18,
    tanks: tanks,
    profile: profile,
  );

  test('the dive divides by underwater and surface minutes', () {
    final d = dive();
    // 40 minutes at 18 m and 10 at 0 m: 50 minutes at a depth of 14.4 m.
    final ambient = d.environment.pressureAtDepth(18 * 40 / 50);
    expect(d.sac, closeTo(100 / 50 / ambient, 1e-9));
  });

  test('entered minutes alone give no rate to a dive with no runtime', () {
    // The statistics leave a dive with no runtime out, so the dive does too.
    final d = dive().copyWith(runtime: Duration.zero);
    expect(d.sac, isNull);
  });

  test('a dive with none entered is unchanged', () {
    final d = dive(
      tanks: const [DiveTank(id: 't', startPressure: 200, endPressure: 100)],
    );
    expect(d.sac, closeTo(100 / 40 / d.environment.pressureAtDepth(18), 1e-9));
  });

  test('a suit inflation bottle adds no surface minutes', () {
    final d = dive(
      tanks: const [
        DiveTank(id: 't', startPressure: 200, endPressure: 100),
        DiveTank(
          id: 'suit',
          startPressure: 200,
          endPressure: 180,
          role: TankRole.suitInflation,
          surfaceBreathingDuration: Duration(minutes: 10),
          order: 1,
        ),
      ],
    );
    expect(d.sac, closeTo(100 / 40 / d.environment.pressureAtDepth(18), 1e-9));
  });

  test('the cylinder row on logged pressures agrees with the dive', () {
    final d = dive();
    final row = const GasAnalysisService()
        .calculateCylinderSac(dive: d, profile: const [])
        .single;
    expect(row.usageDuration, const Duration(minutes: 50));
    expect(row.surfaceSeconds, 600);
    expect(row.sacRate, closeTo(d.sac!, 1e-9));
  });

  test('a cylinder rated from its series adds nothing', () {
    // The series only covers what the computer logged, and the surface
    // minutes came after it.
    final profile = [
      for (var t = 0; t <= 40 * 60; t += 10)
        DiveProfilePoint(timestamp: t, depth: 18),
    ];
    final series = [
      for (var t = 0; t <= 40 * 60; t += 10)
        TankPressurePoint(
          tankId: 't',
          timestamp: t,
          pressure: 200 - t * 90 / (40 * 60),
        ),
    ];
    final row = const GasAnalysisService()
        .calculateCylinderSac(
          dive: dive(profile: profile),
          profile: profile,
          tankPressures: {'t': series},
        )
        .single;
    expect(row.usageDuration, const Duration(minutes: 40));
    expect(row.surfaceSeconds, 0);
  });
}
