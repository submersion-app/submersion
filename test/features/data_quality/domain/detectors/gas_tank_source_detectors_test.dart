import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/gas_mod_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/source_conflict_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/tank_assignment_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

import '../../helpers/quality_test_helpers.dart';

domain.DiveTank tank({
  String id = 't1',
  double o2 = 21.0,
  int order = 0,
  double? volume = 12,
  String? transmitterSerial,
}) => domain.DiveTank(
  id: id,
  volume: volume,
  gasMix: domain.GasMix(o2: o2, he: 0),
  order: order,
  transmitterSerial: transmitterSerial,
);

GasSwitch sw({
  required String id,
  required int t,
  required String tankId,
  double? depth,
}) => GasSwitch(
  id: id,
  diveId: 'd1',
  timestamp: t,
  tankId: tankId,
  depth: depth,
  createdAt: DateTime.utc(2026, 7, 1),
);

void main() {
  final entry = DateTime.utc(2026, 7, 1, 10);

  group('GasModDetector', () {
    const det = GasModDetector();

    test('EAN50 held at 35 m sustains ppO2 2.25 -> critical', () {
      // ppO2 = 0.50 * (35/10 + 1) = 0.50 * 4.5 = 2.25 >= 1.8.
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(o2: 50)]),
        samples: flatProfile(depth: 35),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.critical);
      expect(out.single.params['peakPpO2'], closeTo(2.25, 1e-9));
    });

    test('air at 30 m is clean (ppO2 0.84)', () {
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(o2: 21)]),
        samples: flatProfile(depth: 30),
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('switch to EAN50 recorded at 30 m exceeds its 22 m MOD', () {
      // MOD(1.6, 0.50) = (1.6/0.5 - 1) * 10 = 22 m; 30 > 22 + 1.
      final tanks = [
        tank(id: 'back', o2: 21),
        tank(id: 'deco', o2: 50, order: 1),
      ];
      final ctx = makeContext(
        dive: makeTestDive(tanks: tanks),
        samples: flatProfile(depth: 20), // shallow profile: no ppO2 run
        gasSwitches: [sw(id: 'gs1', t: 1200, tankId: 'deco', depth: 30)],
      );
      final out = det.detect(ctx);
      final modFinding = out.singleWhere(
        (f) => f.params.containsKey('modMeters'),
      );
      expect(modFinding.params['modMeters'], closeTo(22.0, 1e-9));
      expect(modFinding.params['switchDepth'], 30);
    });

    test('CCR dives are skipped entirely', () {
      final dive = makeTestDive(tanks: [tank(o2: 50)]);
      final ccrDive = dive.copyWith(diveMode: DiveMode.ccr);
      final ctx = makeContext(dive: ccrDive, samples: flatProfile(depth: 35));
      expect(det.detect(ctx), isEmpty);
    });

    test('OC dive with no tanks yields nothing', () {
      final ctx = makeContext(
        dive: makeTestDive(tanks: const []),
        samples: flatProfile(depth: 35),
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('EAN50 held at 24 m sustains ppO2 1.7 -> warning', () {
      // ppO2 = 0.50 * (24/10 + 1) = 1.7: above warn (1.6), below critical (1.8).
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(o2: 50)]),
        samples: flatProfile(depth: 24),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.warning);
      expect(out.single.params['peakPpO2'], closeTo(1.7, 1e-9));
    });

    test('honours a lowered diver ppO2 ceiling for the sustained run', () {
      // EAN32 at 35 m: ppO2 = 0.32 * 4.5 = 1.44. Clean on the default 1.6
      // ceiling, a warning for a diver who set their max to 1.4.
      final dive = makeTestDive(tanks: [tank(o2: 32)]);
      final samples = flatProfile(depth: 35);
      expect(det.detect(makeContext(dive: dive, samples: samples)), isEmpty);

      final out = det.detect(
        makeContext(dive: dive, samples: samples, ppO2MaxBar: 1.4),
      );
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.warning);
      expect(out.single.params['peakPpO2'], closeTo(1.44, 1e-9));
    });

    test('honours a lowered diver ppO2 ceiling for the switch MOD', () {
      // MOD(1.4, 0.50) = 18 m; a switch at 22 m is past it only once the
      // diver's ceiling drops from the default 1.6 (MOD 22 m) to 1.4.
      final tanks = [
        tank(id: 'back', o2: 21),
        tank(id: 'deco', o2: 50, order: 1),
      ];
      final dive = makeTestDive(tanks: tanks);
      final switches = [sw(id: 'gs1', t: 1200, tankId: 'deco', depth: 22)];

      expect(
        det.detect(
          makeContext(
            dive: dive,
            samples: flatProfile(depth: 18),
            gasSwitches: switches,
          ),
        ),
        isEmpty,
      );

      final out = det.detect(
        makeContext(
          dive: dive,
          samples: flatProfile(depth: 18),
          gasSwitches: switches,
          ppO2MaxBar: 1.4,
        ),
      );
      final modFinding = out.singleWhere(
        (f) => f.params.containsKey('modMeters'),
      );
      expect(modFinding.params['modMeters'], closeTo(18.0, 1e-9));
    });

    test('a brief ppO2 excursion under the sustain window is not flagged', () {
      // One 1.7-bar sample, then shallow: the run is 0 s < ppO2SustainSeconds.
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(o2: 50)]),
        samples: const [
          QualitySample(t: 0, depth: 24),
          QualitySample(t: 10, depth: 5),
          QualitySample(t: 20, depth: 5),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('hypoxic 10/90 breathed at the surface is flagged', () {
      // fo2 0.10 < hypoxicFo2, depth < 3 m sustained for the whole profile.
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(o2: 10)]),
        samples: flatProfile(depth: 2),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['o2Percent'], closeTo(10.0, 1e-9));
    });

    test('switch-MOD guards skip null depth, unknown tank and zero-O2', () {
      final tanks = [
        tank(id: 'back', o2: 21),
        tank(id: 'zero', o2: 0, order: 1),
      ];
      final ctx = makeContext(
        dive: makeTestDive(tanks: tanks),
        samples: const [], // no ppO2/hypoxic runs
        gasSwitches: [
          sw(id: 'g-nodepth', t: 600, tankId: 'back', depth: null),
          sw(id: 'g-unknown', t: 700, tankId: 'ghost', depth: 30),
          sw(id: 'g-zero', t: 800, tankId: 'zero', depth: 30),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });
  });

  group('TankAssignmentDetector', () {
    const det = TankAssignmentDetector();

    test('drop concentrated while tank inactive is flagged', () {
      // Switch to deco at t=1200. Back tank drops 30 bar AFTER 1200 (100%
      // inactive drop > 70%, total 30 > 20).
      final tanks = [tank(id: 'back'), tank(id: 'deco', o2: 50, order: 1)];
      final backSeries = [
        const QualityPressureSample(t: 0, bar: 200),
        const QualityPressureSample(t: 1200, bar: 200),
        const QualityPressureSample(t: 1800, bar: 185),
        const QualityPressureSample(t: 2400, bar: 170),
      ];
      final ctx = makeContext(
        dive: makeTestDive(tanks: tanks),
        pressures: {'back': backSeries},
        gasSwitches: [sw(id: 'gs1', t: 1200, tankId: 'deco')],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['tankId'], 'back');
      expect(out.single.params['inactiveDropBar'], closeTo(30, 1e-9));
    });

    test('twin series on two tanks flags a double-assigned transmitter', () {
      final series = [
        for (var t = 0; t <= 1200; t += 60)
          QualityPressureSample(t: t, bar: 200 - t * 0.05),
      ];
      final ctx = makeContext(
        dive: makeTestDive(
          tanks: [
            tank(id: 'a'),
            tank(id: 'b', order: 1),
          ],
        ),
        pressures: {'a': series, 'b': series},
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['meanDiffBar'], 0.0);
    });

    test('two tanks on the same transmitter serial are twins, no series '
        'needed', () {
      // Two computers paired to one transmitter, consolidated before the
      // serial gate existed: the same cylinder sits on the dive twice. The
      // serial alone is proof, whatever the pressure series look like.
      final ctx = makeContext(
        dive: makeTestDive(
          tanks: [
            tank(id: 'a', o2: 31, transmitterSerial: '180777'),
            tank(id: 'b', o2: 32, order: 1, transmitterSerial: '180777'),
          ],
        ),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['tankIdA'], 'a');
      expect(out.single.params['tankIdB'], 'b');
      expect(out.single.params['sameTransmitter'], isTrue);
    });

    test('tanks on different transmitter serials are never twins, even with '
        'identical series', () {
      // Twin cylinders on the same mix each carry their own transmitter;
      // matching curves are a coincidence, not a double assignment.
      final series = [
        for (var t = 0; t <= 1200; t += 60)
          QualityPressureSample(t: t, bar: 200 - t * 0.05),
      ];
      final ctx = makeContext(
        dive: makeTestDive(
          tanks: [
            tank(id: 'a', transmitterSerial: '180777'),
            tank(id: 'b', order: 1, transmitterSerial: '180778'),
          ],
        ),
        pressures: {'a': series, 'b': series},
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('twin series logged on offset cadences are still matched', () {
      // Two computers at 10 s cadence, consolidated with a 3 s offset: no
      // two samples share a timestamp, but the curves are the same. Nearest
      // samples within the gap tolerance must be compared.
      final a = [
        for (var t = 0; t <= 1200; t += 10)
          QualityPressureSample(t: t, bar: 200 - t * 0.05),
      ];
      final b = [
        for (var t = 3; t <= 1200; t += 10)
          QualityPressureSample(t: t, bar: 200 - t * 0.05),
      ];
      final ctx = makeContext(
        dive: makeTestDive(
          tanks: [
            tank(id: 'a'),
            tank(id: 'b', order: 1),
          ],
        ),
        pressures: {'a': a, 'b': b},
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['meanDiffBar'], lessThan(1.0));
    });

    test('a zero sentinel serial on two tanks is not a shared transmitter', () {
      final ctx = makeContext(
        dive: makeTestDive(
          tanks: [
            tank(id: 'a', transmitterSerial: '0'),
            tank(id: 'b', order: 1, transmitterSerial: ' 0 '),
          ],
        ),
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('twin series are matched even when a series arrives out of order', () {
      // Sorting is skipped for already-ordered input; this pins that an
      // unordered series is still put in time order before the walk.
      final a = [
        for (var t = 0; t <= 1200; t += 60)
          QualityPressureSample(t: t, bar: 200 - t * 0.05),
      ];
      final b = a.reversed.toList();
      final ctx = makeContext(
        dive: makeTestDive(
          tanks: [
            tank(id: 'a'),
            tank(id: 'b', order: 1),
          ],
        ),
        pressures: {'a': a, 'b': b},
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['meanDiffBar'], 0.0);
    });

    test('single-tank dives are skipped', () {
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank()]),
        pressures: {
          't1': [
            const QualityPressureSample(t: 0, bar: 200),
            const QualityPressureSample(t: 2400, bar: 60),
          ],
        },
      );
      expect(det.detect(ctx), isEmpty);
    });
  });

  group('SourceConflictDetector', () {
    const det = SourceConflictDetector();

    DiveDataSource source({
      required String id,
      bool primary = false,
      double? maxDepth,
      int? duration,
      double? waterTemp,
    }) => DiveDataSource(
      id: id,
      diveId: 'd1',
      isPrimary: primary,
      maxDepth: maxDepth,
      duration: duration,
      waterTemp: waterTemp,
      importedAt: entry,
      createdAt: entry,
    );

    test('two sources 40 vs 41 m agree within tolerance', () {
      // tol = max(2, 40 * 0.05) = 2; diff 1 <= 2.
      final ctx = makeContext(
        dive: makeTestDive(),
        sources: [
          source(id: 'p', primary: true, maxDepth: 40),
          source(id: 's', maxDepth: 41),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('30 vs 36 m conflict flags a warning with no salinity hint', () {
      final ctx = makeContext(
        dive: makeTestDive(),
        sources: [
          source(id: 'p', primary: true, maxDepth: 30),
          source(id: 's', maxDepth: 36),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.warning);
      expect(out.single.params['salinitySettingSuspected'], false);
      expect(out.single.params['depthRatio'], closeTo(1.2, 1e-9));
    });

    test('duration and temperature disagreements are info findings', () {
      final ctx = makeContext(
        dive: makeTestDive(),
        sources: [
          source(id: 'p', primary: true, duration: 2400, waterTemp: 20),
          source(id: 's', duration: 3000, waterTemp: 26),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(2));
      expect(out.map((f) => f.severity).toSet(), {QualitySeverity.info});
    });
  });
}
