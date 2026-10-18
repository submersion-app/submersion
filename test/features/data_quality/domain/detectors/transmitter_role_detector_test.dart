import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/transmitter_role_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

import '../../helpers/quality_test_helpers.dart';

/// Issue #3307: a Shearwater reads a CCR transmitter's role off its name, so
/// a bailout named "OC" arrives as the O2 supply. When it only drained after
/// the diver switched to open circuit, it was the bailout.
void main() {
  const detector = TransmitterRoleDetector();

  domain.DiveTank tank(
    String id,
    int order,
    TankRole role, {
    TankRoleSource? roleSource,
    String? computerId,
  }) => domain.DiveTank(
    id: id,
    order: order,
    role: role,
    roleSource: roleSource,
    computerId: computerId,
  );

  final tx = tank(
    'tx',
    1,
    TankRole.oxygenSupply,
    roleSource: TankRoleSource.transmitterName,
  );
  final dil = tank('dil', 0, TankRole.diluent);
  final oc = tank('oc', 2, TankRole.bailout);

  List<QualityPressureSample> series(
    int from,
    int to,
    double start,
    double r,
  ) => [
    for (var t = from; t <= to; t += 10)
      QualityPressureSample(t: t, bar: start - r * (t - from) / 60),
  ];

  final bailoutShape = [
    ...series(0, 2390, 200, 0),
    ...series(2400, 3000, 200, 6),
  ];
  final switchToOc = GasSwitch(
    id: 's1',
    diveId: 'd1',
    timestamp: 2400,
    tankId: 'oc',
    createdAt: DateTime.utc(2026, 7, 1),
  );

  DiveQualityContext ctx({
    DiveMode mode = DiveMode.ccr,
    List<domain.DiveTank>? tanks,
    Map<String, List<QualityPressureSample>>? pressures,
  }) => makeContext(
    dive: makeTestDive(
      diveMode: mode,
      tanks: tanks ?? [dil, tx, oc],
      runtime: const Duration(minutes: 60),
    ),
    samples: flatProfile(durationSeconds: 3600),
    pressures: pressures ?? {'tx': bailoutShape},
    gasSwitches: [switchToOc],
  );

  test('flags an O-named tank breathed only on open circuit', () {
    final findings = detector.detect(ctx());
    expect(findings, hasLength(1));
    final p = findings.single.params;
    expect(p['tankId'], 'tx');
    expect(p['tankPosition'], 1);
    expect(p['ocTankId'], 'oc');
    expect((p['ocDropBar']! as num).toDouble(), closeTo(60, 0.001));
    expect(p['role'], 'oxygenSupply');
  });

  test('ignores a role the diver set', () {
    final mine = tank('tx', 1, TankRole.oxygenSupply);
    expect(detector.detect(ctx(tanks: [dil, mine, oc])), isEmpty);
  });

  test('ignores OC and SCR dives', () {
    expect(detector.detect(ctx(mode: DiveMode.oc)), isEmpty);
    expect(detector.detect(ctx(mode: DiveMode.scr)), isEmpty);
  });

  test('ignores a tank with no pressure series', () {
    expect(detector.detect(ctx(pressures: const {})), isEmpty);
  });

  test('finding ids are stable across scans', () {
    expect(detector.detect(ctx()).single.id, detector.detect(ctx()).single.id);
  });

  // Review: two computers each log a switch to their own OC cylinder; only
  // the transmitter's own computer's switches describe it.
  test('reads only the switches of the tank\'s own computer', () {
    final tx1 = tank(
      'tx',
      1,
      TankRole.oxygenSupply,
      roleSource: TankRoleSource.transmitterName,
      computerId: 'c1',
    );
    final findings = detector.detect(
      makeContext(
        dive: makeTestDive(
          diveMode: DiveMode.ccr,
          tanks: [
            dil,
            tx1,
            tank('oc1', 2, TankRole.bailout, computerId: 'c1'),
            tank('oc2', 3, TankRole.bailout, computerId: 'c2'),
          ],
          runtime: const Duration(minutes: 60),
        ),
        samples: flatProfile(durationSeconds: 3600),
        pressures: {'tx': bailoutShape},
        gasSwitches: [
          GasSwitch(
            id: 's1',
            diveId: 'd1',
            timestamp: 2400,
            tankId: 'oc1',
            computerId: 'c1',
            createdAt: DateTime.utc(2026, 7, 1),
          ),
          GasSwitch(
            id: 's2',
            diveId: 'd1',
            timestamp: 2410,
            tankId: 'oc2',
            computerId: 'c2',
            createdAt: DateTime.utc(2026, 7, 1),
          ),
        ],
      ),
    );
    expect(findings.single.params['ocTankId'], 'oc1');
  });

  // Review: the finding numbers the tank as the dive page does, by position,
  // not by a stored order that can have gaps after a merge.
  test('numbers the tank by its position, not its stored order', () {
    final findings = detector.detect(
      ctx(
        tanks: [
          dil,
          tank(
            'tx',
            3,
            TankRole.oxygenSupply,
            roleSource: TankRoleSource.transmitterName,
          ),
          tank('oc', 5, TankRole.bailout),
        ],
      ),
    );
    expect(findings.single.params['tankPosition'], 1);
  });

  // Review: on a consolidated dive the merged series can be the other
  // computer's; the check reads the series its own computer logged.
  test('reads the series the tank\'s own computer logged', () {
    final o2Shape = [
      ...series(0, 2400, 200, 0.5),
      ...series(2410, 3000, 180, 0),
    ];
    final findings = detector.detect(
      makeContext(
        dive: makeTestDive(
          diveMode: DiveMode.ccr,
          tanks: [dil, tx, oc],
          runtime: const Duration(minutes: 60),
        ),
        samples: flatProfile(durationSeconds: 3600),
        pressures: {'tx': bailoutShape},
        ownComputerPressures: {'tx': o2Shape},
        gasSwitches: [switchToOc],
      ),
    );
    expect(findings, isEmpty);
  });
}
