import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/pressure_anomaly_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../helpers/quality_test_helpers.dart';

/// An Avelo Hydrotank's pressure rises when the diver pumps water in to get
/// heavier and falls when it is pushed out (issue #4657). That is how it is
/// used, not a fault in the log: the rise, swap and consumption checks leave
/// it alone, while the same readings on back gas are still flagged.
void main() {
  const det = PressureAnomalyDetector();

  domain.DiveTank tank(TankRole role, {double start = 200, double end = 185}) =>
      domain.DiveTank(
        id: 't1',
        volume: 10,
        startPressure: start,
        endPressure: end,
        gasMix: const domain.GasMix(o2: 21),
        role: role,
      );

  // A pump-in at 10 minutes: 20 bar in 30 s, then a steady fall.
  const pumped = [
    QualityPressureSample(t: 0, bar: 200),
    QualityPressureSample(t: 600, bar: 195),
    QualityPressureSample(t: 610, bar: 202),
    QualityPressureSample(t: 620, bar: 209),
    QualityPressureSample(t: 630, bar: 215),
    QualityPressureSample(t: 2400, bar: 185),
  ];

  List<QualityFinding> findings(TankRole role, {double end = 185}) =>
      det.detect(
        makeContext(
          dive: makeTestDive(tanks: [tank(role, end: end)]),
          pressures: {'t1': pumped},
        ),
      );

  bool rises(List<QualityFinding> out) =>
      out.any((f) => f.params.containsKey('riseBar'));

  test('a pump-in on the Hydrotank is no pressure rise', () {
    expect(rises(findings(TankRole.hydrotank)), isFalse);
  });

  test('the same readings on back gas are still a rise', () {
    expect(rises(findings(TankRole.backGas)), isTrue);
  });

  test('a Hydrotank that ends above its start is no swapped pressure', () {
    // Water still in the tank at the end squeezes the gas above its start.
    final out = det.detect(
      makeContext(
        dive: makeTestDive(tanks: [tank(TankRole.hydrotank, end: 230)]),
      ),
    );
    expect(out.where((f) => f.params.containsKey('startBar')), isEmpty);
  });

  test('a fast Hydrotank drop is no implausible consumption', () {
    // Water pushed out drops the pressure far faster than breathing could.
    // 150 bar out of 10 L in 5 minutes at 10 m reads as 150 L/min.
    const purged = [
      QualityPressureSample(t: 0, bar: 200),
      QualityPressureSample(t: 300, bar: 50),
    ];
    List<QualityFinding> out(TankRole role) => det.detect(
      makeContext(
        dive: makeTestDive(avgDepth: 10, tanks: [tank(role, end: 50)]),
        samples: flatProfile(depth: 10, durationSeconds: 300),
        pressures: {'t1': purged},
      ),
    );
    bool consumption(List<QualityFinding> f) =>
        f.any((x) => x.params.containsKey('surfaceLpm'));

    expect(consumption(out(TankRole.backGas)), isTrue);
    expect(consumption(out(TankRole.hydrotank)), isFalse);
  });

  test('a purge and pump-in back on the Hydrotank is no dropout', () {
    // 15 bar out and back within a minute: a dip by the glitch rules.
    const adjusted = [
      QualityPressureSample(t: 0, bar: 200),
      QualityPressureSample(t: 600, bar: 199),
      QualityPressureSample(t: 630, bar: 184),
      QualityPressureSample(t: 660, bar: 198),
      QualityPressureSample(t: 2400, bar: 185),
    ];
    bool dropout(TankRole role) => det
        .detect(
          makeContext(
            dive: makeTestDive(tanks: [tank(role)]),
            pressures: {'t1': adjusted},
          ),
        )
        .any((f) => f.params.containsKey('dropoutCount'));

    expect(dropout(TankRole.backGas), isTrue);
    expect(dropout(TankRole.hydrotank), isFalse);
  });
}
