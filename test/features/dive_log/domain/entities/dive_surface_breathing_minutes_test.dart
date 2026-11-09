import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
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

  test('a cylinder with a transmitter log adds no surface minutes', () {
    // Its end pressure is the transmitter's last reading, taken before the
    // computer stopped, so it holds none of the gas breathed after.
    final d = dive(tanks: [tank.copyWith(hasPressureSeries: true)]);
    expect(d.sac, closeTo(100 / 40 / d.environment.pressureAtDepth(18), 1e-9));
    expect(
      d.rmvFor(GasModel.ideal),
      dive(
        tanks: const [DiveTank(id: 't', startPressure: 200, endPressure: 100)],
      ).rmvFor(GasModel.ideal),
    );
  });

  test('a cylinder logged by a transmitter keeps no row minutes either', () {
    // The transmitter showed no drop, so the row falls back to the logged
    // pressures, whose end is still the transmitter's.
    final d = dive(tanks: [tank.copyWith(hasPressureSeries: true)]);
    final row = const GasAnalysisService()
        .calculateCylinderSac(dive: d, profile: const [])
        .single;
    expect(row.surfaceSeconds, 0);
    expect(row.usageDuration, const Duration(minutes: 40));
  });

  test('a cylinder with no logged drop adds no surface minutes', () {
    // Its gas is not in the rate, so neither is its time.
    final d = dive(
      tanks: const [
        DiveTank(id: 't', startPressure: 200, endPressure: 100),
        DiveTank(
          id: 'o2',
          gasMix: GasMix(o2: 100),
          role: TankRole.deco,
          surfaceBreathingDuration: Duration(minutes: 10),
          order: 1,
        ),
      ],
    );
    expect(d.sac, closeTo(100 / 40 / d.environment.pressureAtDepth(18), 1e-9));
  });

  test('a matched pair counts its shared surface minutes once', () {
    // Sidemount cylinders breathed in turns: ten minutes entered on each is
    // ten minutes of the diver's time, not twenty.
    DiveTank side(String id, TankRole role) => DiveTank(
      id: id,
      volume: 11,
      startPressure: 200,
      endPressure: 100,
      role: role,
      surfaceBreathingDuration: const Duration(minutes: 10),
    );
    final d = dive(
      tanks: [
        side('l', TankRole.sidemountLeft),
        side('r', TankRole.sidemountRight),
      ],
    );
    final ambient = d.environment.pressureAtDepth(18 * 40 / 50);
    expect(d.sac, closeTo(200 / 50 / ambient, 1e-9));
  });

  test('a cylinder left out of a rate adds none of its minutes', () {
    // An unsized stage is not converted into the back gas's bar, nor into
    // litres, so its gas is in neither rate and its minutes must not be.
    final d = dive(
      tanks: const [
        DiveTank(
          id: 'back',
          volume: 12,
          startPressure: 200,
          endPressure: 100,
          role: TankRole.backGas,
        ),
        DiveTank(
          id: 'stage',
          startPressure: 200,
          endPressure: 150,
          gasMix: GasMix(o2: 50),
          role: TankRole.stage,
          surfaceBreathingDuration: Duration(minutes: 10),
          order: 1,
        ),
      ],
    );
    final ambient = d.environment.pressureAtDepth(18);
    expect(d.sac, closeTo(100 / 40 / ambient, 1e-9));
    final rmv = d.rmvFor(GasModel.ideal)!;
    expect(rmv, closeTo(100 * 12 / 40 / ambient, 1e-6));
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
