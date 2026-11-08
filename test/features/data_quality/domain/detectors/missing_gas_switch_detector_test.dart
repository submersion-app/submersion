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
}) => makeContext(
  dive: makeTestDive(
    diveMode: diveMode,
    tanks: [
      tank(id: 'back', order: 0),
      tank(id: 'deco', order: 1, o2: 50, role: decoRole),
    ],
  ),
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
    expect(first['tankPosition'], 2);
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

  test('a start deeper than the gas MOD is reported, never suggested', () {
    final finding = missingSwitchFinding(det.detect(decoDive(switchDepth: 40)));

    expect(finding, isNotNull);
    expect(finding!.params['missingSwitches'], isEmpty);
    final deep = (finding.params['deepStarts'] as List).single as Map;
    expect(deep['tankId'], 'deco');
    expect(deep['tankPosition'], 2);
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
}
