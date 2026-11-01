import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/gas_mod_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/pressure_anomaly_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

import '../../helpers/quality_test_helpers.dart';

List<QualitySample> _flat(double depth, int seconds) => [
  for (var t = 0; t <= seconds; t += 10) QualitySample(t: t, depth: depth),
];

/// Issue #3958: a finding about a logged dive reads the dive's own pressure,
/// so an altitude dive is not flagged for a ppO2 it never reached.
void main() {
  domain.Dive atAltitude(domain.Dive dive) =>
      dive.copyWith(altitude: 3000, waterType: WaterType.fresh);

  test('the gas detector versions moved with their rules', () {
    expect(const GasModDetector().version, 3);
    expect(const PressureAnomalyDetector().version, 5);
  });

  group('GasModDetector', () {
    const detector = GasModDetector();
    final dive = makeTestDive(
      tanks: const [
        domain.DiveTank(id: 't1', volume: 12, gasMix: domain.GasMix(o2: 36)),
      ],
    );

    test('flags EAN36 at 35 m on the flat model', () {
      final out = detector.detect(
        makeContext(dive: dive, samples: _flat(35, 600)),
      );

      expect(out, hasLength(1));
    });

    test('does not flag it at 3000 m in fresh water, under the limit', () {
      final out = detector.detect(
        makeContext(dive: atAltitude(dive), samples: _flat(35, 600)),
      );

      expect(out, isEmpty);
    });

    test('reports the peak in the dive\'s own pressure', () {
      final altitude = atAltitude(
        makeTestDive(
          tanks: const [
            domain.DiveTank(
              id: 't1',
              volume: 12,
              gasMix: domain.GasMix(o2: 50),
            ),
          ],
        ),
      );
      final out = detector.detect(
        makeContext(dive: altitude, samples: _flat(35, 600)),
      );

      expect(
        out.single.params['peakPpO2'],
        closeTo(altitude.environment.pressureAtDepth(35) * 0.5, 1e-9),
      );
    });
  });

  group('GasModDetector switches', () {
    const detector = GasModDetector();
    const tanks = [
      domain.DiveTank(id: 'back', volume: 12, gasMix: domain.GasMix(o2: 21)),
      domain.DiveTank(
        id: 'deco',
        volume: 12,
        gasMix: domain.GasMix(o2: 50),
        order: 1,
      ),
    ];
    final switchAt24 = GasSwitch(
      id: 's1',
      diveId: 'd1',
      timestamp: 300,
      tankId: 'deco',
      depth: 24,
      createdAt: DateTime.utc(2026, 7, 1),
    );

    test('24 m is past the EAN50 MOD on the flat model', () {
      final out = detector.detect(
        makeContext(
          dive: makeTestDive(tanks: tanks),
          gasSwitches: [switchAt24],
        ),
      );

      expect(
        out.where((f) => f.params.containsKey('switchDepth')),
        hasLength(1),
      );
    });

    test('24 m is within it at 3000 m in fresh water', () {
      final out = detector.detect(
        makeContext(
          dive: atAltitude(makeTestDive(tanks: tanks)),
          gasSwitches: [switchAt24],
        ),
      );

      expect(out.where((f) => f.params.containsKey('switchDepth')), isEmpty);
    });
  });

  group('PressureAnomalyDetector', () {
    test('the implausible SAC check divides by the dive\'s own pressure', () {
      final dive = atAltitude(
        makeTestDive(
          avgDepth: 10,
          tanks: const [domain.DiveTank(id: 't1', volume: 12, endPressure: 50)],
        ),
      );
      final out = const PressureAnomalyDetector().detect(
        makeContext(
          dive: dive,
          samples: _flat(10, 300),
          pressures: {
            't1': const [
              QualityPressureSample(t: 0, bar: 200),
              QualityPressureSample(t: 300, bar: 50),
            ],
          },
        ),
      );

      expect(
        out
            .singleWhere((f) => f.params.containsKey('surfaceLpm'))
            .params['surfaceLpm'],
        closeTo(150 * 12 / 5 / dive.environment.pressureAtDepth(10), 1e-6),
      );
    });
  });
}
