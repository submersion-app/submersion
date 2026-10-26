import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/tank_assignment_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

import '../../helpers/quality_test_helpers.dart';

domain.DiveTank tank({
  required String id,
  required int order,
  TankRole role = TankRole.backGas,
  TankRoleSource? roleSource,
  double o2 = 21.0,
}) => domain.DiveTank(
  id: id,
  volume: 3,
  gasMix: domain.GasMix(o2: o2, he: 0),
  order: order,
  role: role,
  roleSource: roleSource,
);

GasSwitch sw({required String id, required int t, required String tankId}) =>
    GasSwitch(
      id: id,
      diveId: 'd1',
      timestamp: t,
      tankId: tankId,
      createdAt: DateTime.utc(2026, 7, 1),
    );

/// One sample every 10 s from [from] to [to] (inclusive), dropping
/// [barPerMinute] from [startBar].
List<QualityPressureSample> series(
  int from,
  int to,
  double startBar,
  double barPerMinute,
) => [
  for (var t = from; t <= to; t += 10)
    QualityPressureSample(t: t, bar: startBar - barPerMinute * (t - from) / 60),
];

/// Issue #3652: CCR loop cylinders (diluent, O2 supply) both drain while the
/// diver is on the loop, and no computer logs the O2 flow as a gas switch.
/// The open-circuit idle-tank check must not judge them; their drain rate on
/// the loop is compared with their drain rate on open circuit instead.
void main() {
  const det = TankAssignmentDetector();

  test('dive #914: an O2 supply draining on the loop is not flagged', () {
    // Diluent 180 -> 96 bar, O2 supply 193 -> 163 bar, and one logged
    // switch, to the diluent. The O2 supply never counts as "active" under
    // the open-circuit model, so all 30 bar used to read as idle use.
    final ctx = makeContext(
      dive: makeTestDive(
        diveMode: DiveMode.ccr,
        tanks: [
          tank(id: 'dil', order: 0, role: TankRole.diluent),
          tank(id: 'o2', order: 1, role: TankRole.oxygenSupply, o2: 100),
        ],
      ),
      pressures: {
        'dil': series(0, 3600, 180, 1.4),
        'o2': series(0, 3600, 193, 0.5),
      },
      gasSwitches: [sw(id: 'gs1', t: 0, tankId: 'dil')],
    );
    expect(det.detect(ctx), isEmpty);
  });

  test('an O2 supply ordered before the diluent is not flagged either', () {
    // The default before the first switch is the lowest-ordered tank; with
    // the O2 supply first and a switch to the diluent, the O2 supply's whole
    // drop after that switch used to count as idle.
    final ctx = makeContext(
      dive: makeTestDive(
        diveMode: DiveMode.ccr,
        tanks: [
          tank(id: 'o2', order: 0, role: TankRole.oxygenSupply, o2: 100),
          tank(id: 'dil', order: 1, role: TankRole.diluent),
        ],
      ),
      pressures: {'o2': series(0, 3600, 193, 0.5)},
      gasSwitches: [sw(id: 'gs1', t: 60, tankId: 'dil')],
    );
    expect(det.detect(ctx), isEmpty);
  });

  test('a loop tank is judged by role even on a dive not marked CCR', () {
    // A rebreather dive imported with the default open-circuit mode still
    // carries loop roles, and those roles never appear on a real OC dive.
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank(id: 'dil', order: 0, role: TankRole.diluent),
          tank(id: 'o2', order: 1, role: TankRole.oxygenSupply, o2: 100),
        ],
      ),
      pressures: {'o2': series(0, 3600, 193, 0.5)},
      gasSwitches: [sw(id: 'gs1', t: 0, tankId: 'dil')],
    );
    expect(det.detect(ctx), isEmpty);
  });

  test('an mCCR O2 supply bleeding at one rate through a bailout is not '
      'flagged', () {
    // The constant-mass-flow orifice keeps bleeding on open circuit: 1
    // bar/min for the whole hour, bailout at 30 minutes. Half the drop comes
    // on open circuit, but the rate never changes.
    final ctx = makeContext(
      dive: makeTestDive(
        diveMode: DiveMode.ccr,
        tanks: [
          tank(id: 'dil', order: 0, role: TankRole.diluent),
          tank(id: 'o2', order: 1, role: TankRole.oxygenSupply, o2: 100),
          tank(id: 'bo', order: 2, role: TankRole.bailout, o2: 50),
        ],
      ),
      pressures: {
        'o2': series(0, 3600, 200, 1),
        'bo': [...series(0, 1790, 200, 0), ...series(1800, 3600, 200, 3)],
      },
      gasSwitches: [sw(id: 'gs1', t: 1800, tankId: 'bo')],
    );
    expect(det.detect(ctx), isEmpty);
  });

  test('a diver-set O2 supply that drains like a bailout is flagged', () {
    // Flat on the loop, 6 bar/min once the diver switches to open circuit:
    // this series is the bailout's, attributed to the O2 supply.
    final ctx = makeContext(
      dive: makeTestDive(
        diveMode: DiveMode.ccr,
        tanks: [
          tank(id: 'dil', order: 0, role: TankRole.diluent),
          tank(id: 'o2', order: 1, role: TankRole.oxygenSupply, o2: 100),
          tank(id: 'bo', order: 2, role: TankRole.bailout, o2: 50),
        ],
      ),
      pressures: {
        'o2': [...series(0, 2390, 200, 0), ...series(2400, 3000, 200, 6)],
      },
      gasSwitches: [sw(id: 'gs1', t: 2400, tankId: 'bo')],
    );
    final out = det.detect(ctx);
    expect(out, hasLength(1));
    expect(out.single.params['tankId'], 'o2');
    expect(out.single.params['tankOrder'], 1);
    expect(out.single.params['inactiveDropBar'], closeTo(60, 0.001));
    expect(out.single.params['totalDropBar'], closeTo(60, 0.001));
  });

  test('a name-derived loop role on a CCR dive is left to the transmitter '
      'role check', () {
    // TransmitterRoleDetector already reports this cylinder (issue #3307)
    // with a repair that fixes the role; a second finding would repeat it.
    final ctx = makeContext(
      dive: makeTestDive(
        diveMode: DiveMode.ccr,
        tanks: [
          tank(id: 'dil', order: 0, role: TankRole.diluent),
          tank(
            id: 'o2',
            order: 1,
            role: TankRole.oxygenSupply,
            roleSource: TankRoleSource.transmitterName,
            o2: 100,
          ),
          tank(id: 'bo', order: 2, role: TankRole.bailout, o2: 50),
        ],
      ),
      pressures: {
        'o2': [...series(0, 2390, 200, 0), ...series(2400, 3000, 200, 6)],
      },
      gasSwitches: [sw(id: 'gs1', t: 2400, tankId: 'bo')],
    );
    expect(det.detect(ctx), isEmpty);
  });

  test('a bailout draining while on the loop is still flagged', () {
    // Loop tanks leave the open-circuit check; every other cylinder on a
    // CCR dive stays in it.
    final ctx = makeContext(
      dive: makeTestDive(
        diveMode: DiveMode.ccr,
        tanks: [
          tank(id: 'dil', order: 0, role: TankRole.diluent),
          tank(id: 'o2', order: 1, role: TankRole.oxygenSupply, o2: 100),
          tank(id: 'bo', order: 2, role: TankRole.bailout, o2: 50),
        ],
      ),
      pressures: {'bo': series(0, 2400, 200, 1)},
      gasSwitches: [
        sw(id: 'gs1', t: 0, tankId: 'dil'),
        sw(id: 'gs2', t: 2400, tankId: 'bo'),
      ],
    );
    final out = det.detect(ctx);
    expect(out, hasLength(1));
    expect(out.single.params['tankId'], 'bo');
  });
}
