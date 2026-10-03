import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

/// Per-cylinder SAC from a tank's recorded usage duration (issue #1496):
/// MacDive logs how long each cylinder was breathed, with no gas-switch
/// times, so that duration is the only thing that tells two same-role
/// tanks apart.
void main() {
  const service = GasAnalysisService();

  // A flat 20 m dive, one sample every 10 s for an hour.
  final profile = [
    for (var t = 0; t <= 3600; t += 10)
      DiveProfilePoint(timestamp: t, depth: 20.0),
  ];

  Dive makeDive(List<DiveTank> tanks) => Dive(
    id: 'dive-1',
    dateTime: DateTime(2026, 3, 28, 10, 0),
    runtime: const Duration(minutes: 60),
    avgDepth: 20.0,
    tanks: tanks,
    profile: profile,
    gear: looseGear(const []),
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  DiveTank tank(
    String id, {
    TankRole role = TankRole.backGas,
    Duration? usageDuration,
  }) => DiveTank(
    id: id,
    volume: 11.1,
    startPressure: 200,
    endPressure: 100,
    role: role,
    usageDuration: usageDuration,
  );

  CylinderSac sacFor(List<CylinderSac> results, String id) =>
      results.singleWhere((r) => r.tankId == id);

  test('two back-gas tanks each use their own recorded duration', () {
    final results = service.calculateCylinderSac(
      dive: makeDive([
        tank('a', usageDuration: const Duration(minutes: 30)),
        tank('b', usageDuration: const Duration(minutes: 20)),
      ]),
      profile: profile,
    );

    expect(sacFor(results, 'a').usageDuration, const Duration(minutes: 30));
    expect(sacFor(results, 'b').usageDuration, const Duration(minutes: 20));
  });

  test('a recorded duration is the SAC denominator', () {
    final wholeDive = sacFor(
      service.calculateCylinderSac(
        dive: makeDive([tank('a')]),
        profile: profile,
      ),
      'a',
    );
    final halfDive = sacFor(
      service.calculateCylinderSac(
        dive: makeDive([tank('a', usageDuration: const Duration(minutes: 30))]),
        profile: profile,
      ),
      'a',
    );

    // Same gas over half the minutes at the same depth: twice the rate.
    expect(wholeDive.usageDuration, const Duration(minutes: 60));
    expect(halfDive.sacRate, closeTo(wholeDive.sacRate! * 2, 1e-9));
  });

  test('a pressure series is divided by the recorded duration too', () {
    // A transmitter series spanning the whole dive: 200 bar to 100 bar.
    final series = {
      'a': [
        for (var t = 0; t <= 3600; t += 60)
          TankPressurePoint(tankId: 'a', timestamp: t, pressure: 200 - t / 36),
      ],
    };

    double? sacWith(Duration? recorded) => sacFor(
      service.calculateCylinderSac(
        dive: makeDive([tank('a', usageDuration: recorded)]),
        profile: profile,
        tankPressures: series,
      ),
      'a',
    ).sacRate;

    final wholeDive = sacWith(null)!;
    expect(sacWith(const Duration(minutes: 30)), closeTo(wholeDive * 2, 1e-9));
  });

  test('a non-back-gas tank with a recorded duration gets a SAC', () {
    final results = service.calculateCylinderSac(
      dive: makeDive([
        tank('back'),
        tank(
          'stage',
          role: TankRole.stage,
          usageDuration: const Duration(minutes: 15),
        ),
      ]),
      profile: profile,
    );

    final stage = sacFor(results, 'stage');
    expect(stage.usageDuration, const Duration(minutes: 15));
    expect(stage.sacRate, isNotNull);
  });

  test('a non-back-gas tank without one is still skipped', () {
    final results = service.calculateCylinderSac(
      dive: makeDive([tank('back'), tank('stage', role: TankRole.stage)]),
      profile: profile,
    );

    expect(results.map((r) => r.tankId), ['back']);
  });

  test('gas switches win over a recorded duration', () {
    GasSwitchWithTank switchTo(String tankId, int timestamp) =>
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'sw-$tankId',
            diveId: 'dive-1',
            timestamp: timestamp,
            tankId: tankId,
            createdAt: DateTime(2026),
          ),
          tankName: tankId,
          gasMix: 'Air',
          o2Fraction: 0.21,
        );

    final results = service.calculateCylinderSac(
      dive: makeDive([
        tank('a', usageDuration: const Duration(minutes: 5)),
        tank('b', usageDuration: const Duration(minutes: 5)),
      ]),
      profile: profile,
      gasSwitches: [switchTo('a', 0), switchTo('b', 2400)],
    );

    expect(sacFor(results, 'a').usageDuration, const Duration(minutes: 40));
    expect(sacFor(results, 'b').usageDuration, const Duration(minutes: 20));
  });
}
