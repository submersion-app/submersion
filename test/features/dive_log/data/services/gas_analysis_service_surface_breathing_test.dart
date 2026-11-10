import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// Issue #2930: SAC by cylinder puts back surface minutes a cylinder was
/// breathed in, when a switch logged on the surface or a pressure still
/// falling there says so.
void main() {
  const service = GasAnalysisService();

  // 30 minutes at 18 m, then 15 logged at the surface, one sample every 10 s.
  final profile = [
    for (var t = 0; t <= 45 * 60; t += 10)
      DiveProfilePoint(
        timestamp: t,
        depth: t == 0
            ? 0
            : t <= 30 * 60
            ? 18
            : 0.3,
      ),
  ];

  const back = DiveTank(
    id: 'back',
    volume: 12,
    startPressure: 200,
    endPressure: 100,
    role: TankRole.backGas,
  );
  const oxygen = DiveTank(
    id: 'o2',
    volume: 7,
    startPressure: 200,
    endPressure: 170,
    gasMix: GasMix(o2: 100),
    role: TankRole.deco,
    order: 1,
  );

  Dive dive(List<DiveTank> tanks) => Dive(
    id: 'd',
    dateTime: DateTime(2026, 1, 1),
    runtime: const Duration(minutes: 45),
    avgDepth: 12,
    tanks: tanks,
    profile: profile,
  );

  GasSwitchWithTank switchTo(String tankId, int timestamp) => GasSwitchWithTank(
    gasSwitch: GasSwitch(
      id: 'sw-$tankId-$timestamp',
      diveId: 'd',
      timestamp: timestamp,
      tankId: tankId,
      createdAt: DateTime.utc(2026),
    ),
    tankName: tankId,
    gasMix: 'Air',
    o2Fraction: 0.21,
  );

  CylinderSac row(List<CylinderSac> rows, String id) =>
      rows.singleWhere((r) => r.tankId == id);

  test(
    'oxygen switched to on the surface is rated over its surface minutes',
    () {
      final rows = service.calculateCylinderSac(
        dive: dive(const [back, oxygen]),
        profile: profile,
        gasSwitches: [switchTo('back', 0), switchTo('o2', 35 * 60)],
      );

      final o2 = row(rows, 'o2');
      expect(o2.usageDuration, const Duration(minutes: 10));
      expect(o2.avgDepthDuringUse, closeTo(0.3, 1e-9));
      expect(o2.sacRate, isNotNull);
      // The back gas runs on to the switch, past the end of the ascent.
      expect(row(rows, 'back').usageWindows.last.end, 35 * 60);
    },
  );

  test('a back gas still falling on the surface keeps those minutes', () {
    // Steady fall to 110 bar at the end of the ascent, then 10 more bar over
    // the next five minutes of a surface swim, then flat.
    final series = [
      for (var t = 0; t <= 45 * 60; t += 10)
        TankPressurePoint(
          tankId: 'back',
          timestamp: t,
          pressure: t <= 30 * 60
              ? 200 - t * 90 / (30 * 60)
              : t <= 35 * 60
              ? 110 - (t - 30 * 60) * 10 / (5 * 60)
              : 100,
        ),
    ];
    final rows = service.calculateCylinderSac(
      dive: dive(const [back]),
      profile: profile,
      tankPressures: {'back': series},
    );

    expect(row(rows, 'back').usageDuration, const Duration(minutes: 35));
  });

  test('a flat series on the surface leaves the tail out', () {
    final series = [
      for (var t = 0; t <= 45 * 60; t += 10)
        TankPressurePoint(
          tankId: 'back',
          timestamp: t,
          pressure: t <= 30 * 60 ? 200 - t * 100 / (30 * 60) : 100,
        ),
    ];
    final rows = service.calculateCylinderSac(
      dive: dive(const [back]),
      profile: profile,
      tankPressures: {'back': series},
    );

    // The window closes at the sample after the last underwater one.
    expect(
      row(rows, 'back').usageDuration,
      const Duration(minutes: 30, seconds: 10),
    );
  });
}
