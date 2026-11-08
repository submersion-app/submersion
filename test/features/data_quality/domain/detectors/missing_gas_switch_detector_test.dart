import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/missing_gas_switch_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

import '../../helpers/quality_test_helpers.dart';

domain.DiveTank tank({
  required String id,
  required int order,
  TankRole role = TankRole.backGas,
  double o2 = 21.0,
  double he = 0.0,
}) => domain.DiveTank(
  id: id,
  volume: 11,
  gasMix: domain.GasMix(o2: o2, he: he),
  order: order,
  role: role,
);

/// A reading every 10 s from 0 to [end], starting at [startBar] and falling
/// at [barPerMinute] wherever [falling] says the cylinder is being breathed.
List<QualityPressureSample> pressure({
  required int end,
  required double startBar,
  required bool Function(int t) falling,
  double barPerMinute = 2.0,
}) {
  final out = <QualityPressureSample>[];
  var bar = startBar;
  for (var t = 0; t <= end; t += 10) {
    if (t > 0 && falling(t)) bar -= barPerMinute * 10 / 60;
    out.add(QualityPressureSample(t: t, bar: bar));
  }
  return out;
}

/// A depth sample every 10 s from 0 to [end], the depth [depthAt] gives.
List<QualitySample> profile(int end, double Function(int t) depthAt) => [
  for (var t = 0; t <= end; t += 10) QualitySample(t: t, depth: depthAt(t)),
];

GasSwitch sw({required String id, required int t, required String tankId}) =>
    GasSwitch(
      id: id,
      diveId: 'd1',
      timestamp: t,
      tankId: tankId,
      createdAt: DateTime.utc(2026, 7, 1),
    );

/// Back gas breathed to 30:00 at 30 m, then EAN50 from 30:00 at 21 m.
DiveQualityContext decoDive({
  List<GasSwitch> gasSwitches = const [],
  double switchDepth = 21,
  DiveMode diveMode = DiveMode.oc,
  TankRole decoRole = TankRole.deco,
  List<QualitySample>? samples,
  bool switchesEdited = false,
}) => makeContext(
  dive: makeTestDive(
    diveMode: diveMode,
    tanks: [
      tank(id: 'back', order: 0),
      tank(id: 'deco', order: 1, o2: 50, role: decoRole),
    ],
  ).copyWith(gasSwitchesEdited: switchesEdited),
  samples: samples ?? profile(3000, (t) => t < 1800 ? 30 : switchDepth),
  pressures: {
    'back': pressure(end: 3000, startBar: 200, falling: (t) => t <= 1800),
    'deco': pressure(end: 3000, startBar: 200, falling: (t) => t > 1800),
  },
  gasSwitches: gasSwitches,
);

QualityFinding? missingSwitchFinding(List<QualityFinding> findings) {
  expect(findings.length, lessThanOrEqualTo(1));
  return findings.firstOrNull;
}

/// Issue #165: a dive whose cylinder pressures show a switch the computer
/// never logged.
void main() {
  const det = MissingGasSwitchDetector();

  test('a deco bottle breathed with no switch logged is flagged', () {
    final finding = missingSwitchFinding(det.detect(decoDive()));

    expect(finding, isNotNull);
    expect(finding!.severity, QualitySeverity.warning);
    expect(finding.detectorId, 'missing_gas_switch');
    expect(finding.category, QualityCategory.tank);
    expect(finding.computerId, isNull);
    final switches = finding.params['missingSwitches'] as List;
    expect(switches, hasLength(1));
    final first = switches.single as Map;
    expect(first['tankId'], 'deco');
    expect(first['tankPosition'], 1);
    expect(first['t'] as int, closeTo(1800, 30));
    expect(first['depth'], 21);
    expect(first['o2Percent'], 50);
    expect(first['hePercent'], 0);
    expect(finding.params['deepStarts'], isEmpty);
  });

  test('a dive with a logged switch is left to the idle-tank check', () {
    final findings = det.detect(
      decoDive(
        gasSwitches: [sw(id: 'gs1', t: 1800, tankId: 'deco')],
      ),
    );
    expect(missingSwitchFinding(findings), isNull);
  });

  test('a switch list the diver emptied in the editor is left alone', () {
    // An empty list the diver owns is their call, not a missing switch.
    expect(
      missingSwitchFinding(det.detect(decoDive(switchesEdited: true))),
      isNull,
    );
  });

  test('a start deeper than the gas MOD is reported, never suggested', () {
    final finding = missingSwitchFinding(det.detect(decoDive(switchDepth: 40)));

    expect(finding, isNotNull);
    expect(finding!.params['missingSwitches'], isEmpty);
    final deep = (finding.params['deepStarts'] as List).single as Map;
    expect(deep['tankId'], 'deco');
    expect(deep['tankPosition'], 1);
    expect(deep['depth'], 40);
    expect(deep['modMeters'] as double, closeTo(22, 1));
  });

  test('a start within the MOD tolerance is still suggested', () {
    // EAN50's MOD at 1.6 bar is about 22 m; 22.5 m is inside the 1 m
    // allowance the switch-depth check grants.
    final finding = missingSwitchFinding(
      det.detect(decoDive(switchDepth: 22.5)),
    );
    expect(finding!.params['missingSwitches'], hasLength(1));
    expect(finding.params['deepStarts'], isEmpty);
  });

  test('rebreather dives are left to the loop and bailout checks', () {
    final findings = det.detect(decoDive(diveMode: DiveMode.ccr));
    expect(missingSwitchFinding(findings), isNull);
  });

  test('a loop cylinder draining is never a missed switch', () {
    final findings = det.detect(decoDive(decoRole: TankRole.diluent));
    expect(missingSwitchFinding(findings), isNull);
  });

  test('a dive without a depth profile is skipped', () {
    final findings = det.detect(decoDive(samples: const []));
    expect(missingSwitchFinding(findings), isNull);
  });

  test('a single-cylinder dive is skipped', () {
    final ctx = makeContext(
      dive: makeTestDive(tanks: [tank(id: 'back', order: 0)]),
      samples: profile(3000, (_) => 20),
      pressures: {
        'back': pressure(end: 3000, startBar: 200, falling: (t) => t > 1200),
      },
    );
    expect(det.detect(ctx), isEmpty);
  });

  test('a later turn on the starting cylinder alone suggests nothing', () {
    // The first cylinder held, then fell: with nothing breathed before it,
    // the timeline already has it in use, so there is no switch to add.
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank(id: 'back', order: 0),
          tank(id: 'deco', order: 1, o2: 50, role: TankRole.deco),
        ],
      ),
      samples: profile(3000, (_) => 20),
      pressures: {
        'back': pressure(end: 3000, startBar: 200, falling: (t) => t > 600),
        'deco': pressure(end: 3000, startBar: 200, falling: (_) => false),
      },
    );
    expect(missingSwitchFinding(det.detect(ctx)), isNull);
  });

  test('a sidemount rotation suggests every turn, back to the first too', () {
    bool onLeft(int t) => t <= 600 || (t > 1200 && t <= 1800);
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank(id: 'left', order: 0, role: TankRole.sidemountLeft),
          tank(id: 'right', order: 1, role: TankRole.sidemountRight),
        ],
      ),
      samples: profile(2400, (_) => 18),
      pressures: {
        'left': pressure(end: 2400, startBar: 200, falling: onLeft),
        'right': pressure(
          end: 2400,
          startBar: 200,
          falling: (t) => t > 0 && !onLeft(t),
        ),
      },
    );

    final finding = missingSwitchFinding(det.detect(ctx));
    final switches = [
      for (final s in finding!.params['missingSwitches'] as List) s as Map,
    ];
    expect([for (final s in switches) s['tankId']], ['right', 'left', 'right']);
    expect(switches[0]['t'] as int, closeTo(600, 30));
    expect(switches[1]['t'] as int, closeTo(1200, 30));
    expect(switches[2]['t'] as int, closeTo(1800, 30));
  });

  test('one-sided sidemount: every hand-over to the other cylinder', () {
    // Only the right cylinder carries a transmitter. It is breathed from
    // 10:00 to 20:00 and again from 30:00 to 40:00, so the diver was on the
    // left one from 20:00 to 30:00 and from 40:00 to the end.
    bool onRight(int t) => (t > 600 && t <= 1200) || (t > 1800 && t <= 2400);
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank(id: 'left', order: 0, role: TankRole.sidemountLeft),
          tank(id: 'right', order: 1, role: TankRole.sidemountRight),
        ],
      ),
      samples: profile(3000, (_) => 18),
      pressures: {
        'right': pressure(end: 3000, startBar: 200, falling: onRight),
      },
    );

    final finding = missingSwitchFinding(det.detect(ctx));
    final switches = [
      for (final s in finding!.params['missingSwitches'] as List) s as Map,
    ];
    expect(
      [for (final s in switches) s['tankId']],
      ['right', 'left', 'right', 'left'],
    );
    expect(switches[0]['t'] as int, closeTo(600, 30));
    expect(switches[1]['t'] as int, closeTo(1200, 30));
    expect(switches[2]['t'] as int, closeTo(1800, 30));
    expect(switches[3]['t'] as int, closeTo(2400, 30));
    expect(switches[1]['depth'], 18);
    expect(finding.params.containsKey('unplacedRestart'), isFalse);
  });

  test('a back gas transmitter alone shows the switch to the deco bottle', () {
    // The EAN50 carries no transmitter. The diver reaches 21 m at 29:00 and
    // switches at 30:00, where back gas stops falling and then holds.
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank(id: 'back', order: 0),
          tank(id: 'deco', order: 1, o2: 50, role: TankRole.deco),
        ],
      ),
      samples: profile(3000, (t) => t < 1740 ? 30 : 21),
      pressures: {
        'back': pressure(end: 3000, startBar: 200, falling: (t) => t <= 1800),
      },
    );

    final finding = missingSwitchFinding(det.detect(ctx));
    final first = (finding!.params['missingSwitches'] as List).single as Map;
    expect(first['tankId'], 'deco');
    expect(first['t'] as int, closeTo(1800, 30));
    expect(first['depth'], 21);
  });

  test('a cylinder left at the surface hands over to nothing', () {
    // Back gas is breathed until the diver surfaces at 47:50; the
    // transmitter goes on logging the full cylinder at the surface.
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank(id: 'back', order: 0),
          tank(id: 'deco', order: 1, o2: 50, role: TankRole.deco),
        ],
      ),
      samples: profile(3000, (t) => t < 2870 ? 20 : 0),
      pressures: {
        'back': pressure(end: 3000, startBar: 200, falling: (t) => t < 2870),
      },
    );

    expect(missingSwitchFinding(det.detect(ctx)), isNull);
  });

  test('a transmitter that stops reporting hands over to nothing', () {
    // The back gas readings end mid-fall at 30:00; nothing shows it held.
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank(id: 'back', order: 0),
          tank(id: 'deco', order: 1, o2: 50, role: TankRole.deco),
        ],
      ),
      samples: profile(3000, (_) => 20),
      pressures: {
        'back': pressure(end: 1800, startBar: 200, falling: (_) => true),
      },
    );

    expect(missingSwitchFinding(det.detect(ctx)), isNull);
  });

  test('an inferred return deeper than its MOD is named only once', () {
    // Back gas breathed to 10:00, the EAN50 at 40 m from 10:00 to 20:00,
    // then back gas again. The EAN50's own start is the too-deep one; the
    // return inferred from the back gas restart lands on the same moment.
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank(id: 'back', order: 0),
          tank(id: 'deco', order: 1, o2: 50, role: TankRole.deco),
        ],
      ),
      samples: profile(3000, (_) => 40),
      pressures: {
        'back': pressure(
          end: 3000,
          startBar: 200,
          falling: (t) => t <= 600 || t > 1200,
        ),
        'deco': pressure(
          end: 3000,
          startBar: 200,
          falling: (t) => t > 600 && t <= 1200,
        ),
      },
    );

    final finding = missingSwitchFinding(det.detect(ctx));
    expect(finding!.params['missingSwitches'], isEmpty);
    final deep = finding.params['deepStarts'] as List;
    expect(deep, hasLength(1));
    expect((deep.single as Map)['tankId'], 'deco');
  });

  test('a restart with more than two cylinders offers no switch', () {
    // Back gas and the O2 carry no transmitter, so when the EAN50 is
    // breathed again at 30:00 the pressures cannot say which one the diver
    // was on from 20:00.
    bool onDeco(int t) => (t > 600 && t <= 1200) || (t > 1800 && t <= 2400);
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank(id: 'back', order: 0),
          tank(id: 'deco', order: 1, o2: 50, role: TankRole.deco),
          tank(id: 'o2', order: 2, o2: 100, role: TankRole.deco),
        ],
      ),
      samples: profile(3000, (_) => 6),
      pressures: {'deco': pressure(end: 3000, startBar: 200, falling: onDeco)},
    );

    final finding = missingSwitchFinding(det.detect(ctx));
    expect(finding!.params['missingSwitches'], isEmpty);
    final restart = finding.params['unplacedRestart'] as Map;
    expect(restart['tankId'], 'deco');
    expect(restart['tankPosition'], 1);
    expect(restart['t'] as int, closeTo(1800, 30));
  });

  test('a start after the profile ends is not a switch', () {
    // The transmitter kept logging at the surface; the profile stopped at
    // 25:00, before the bottle's start at 30:00.
    final finding = missingSwitchFinding(
      det.detect(decoDive(samples: profile(1500, (_) => 21))),
    );
    expect(finding, isNull);
  });

  test('two cylinders starting on one second suggest the first in dive '
      'order', () {
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank(id: 'back', order: 0),
          tank(id: 'stage-b', order: 2, o2: 50, role: TankRole.stage),
          tank(id: 'stage-a', order: 1, o2: 50, role: TankRole.stage),
        ],
      ),
      samples: profile(3000, (_) => 20),
      pressures: {
        'back': pressure(end: 3000, startBar: 200, falling: (t) => t <= 1800),
        'stage-b': pressure(end: 3000, startBar: 200, falling: (t) => t > 1800),
        'stage-a': pressure(end: 3000, startBar: 200, falling: (t) => t > 1800),
      },
    );

    final finding = missingSwitchFinding(det.detect(ctx));
    final switches = finding!.params['missingSwitches'] as List;
    expect([for (final s in switches) (s as Map)['tankId']], ['stage-a']);
  });

  test('a start between profile samples gets the interpolated depth', () {
    // One sample a minute: 22 m at 30:00, 16 m at 31:00. The bottle starts
    // a few seconds after 30:00, so its depth lies between the two.
    final finding = missingSwitchFinding(
      det.detect(
        decoDive(
          samples: [
            for (var t = 0; t <= 3000; t += 60)
              QualitySample(t: t, depth: t <= 1800 ? 22 : 16),
          ],
        ),
      ),
    );
    final first = (finding!.params['missingSwitches'] as List).single as Map;
    final t = first['t'] as int;
    expect(t, greaterThan(1800));
    expect(t, lessThan(1860));
    expect(first['depth'] as double, closeTo(22 - 6 * (t - 1800) / 60, 1e-9));
  });
}
