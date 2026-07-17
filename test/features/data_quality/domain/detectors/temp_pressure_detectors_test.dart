import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/pressure_anomaly_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/temp_anomaly_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../helpers/quality_test_helpers.dart';

domain.DiveTank tank({
  String id = 't1',
  double? volume = 12.0,
  double? start = 200,
  double? end = 60,
  double o2 = 21.0,
  int order = 0,
}) => domain.DiveTank(
  id: id,
  volume: volume,
  startPressure: start,
  endPressure: end,
  gasMix: domain.GasMix(o2: o2, he: 0),
  order: order,
);

void main() {
  group('TempAnomalyDetector', () {
    const det = TempAnomalyDetector();

    test('26 C tropical profile is clean', () {
      final ctx = makeContext(
        dive: makeTestDive(waterTemp: 26),
        samples: flatProfile(temp: 26),
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('295 C samples flag range with Fahrenheit-as-Kelvin hint', () {
      // The Shearwater F-as-K bug reports ~295 for 72F water.
      final ctx = makeContext(
        dive: makeTestDive(),
        samples: flatProfile(temp: 295),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['fahrenheitAsKelvinSuspected'], true);
    });

    test('8 C jump between adjacent samples is flagged', () {
      final samples = [
        for (var t = 0; t <= 300; t += 10)
          QualitySample(t: t, depth: 20, temp: t == 150 ? 12.0 : 20.0),
      ];
      // Two jumps (into and out of the bad sample), same 5-min bucket ->
      // one finding survives the deterministic-id collapse; assert >= 1.
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      final out = det.detect(ctx);
      expect(out, isNotEmpty);
      expect(out.first.params['deltaC'], closeTo(8.0, 1e-9));
    });

    test('scalar waterTemp of 99 C is flagged without samples', () {
      final ctx = makeContext(dive: makeTestDive(waterTemp: 99));
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['waterTempC'], 99);
    });
  });

  group('PressureAnomalyDetector', () {
    const det = PressureAnomalyDetector();

    test('normal 200->60 bar tank with matching series is clean', () {
      final series = [
        for (var t = 0; t <= 2400; t += 60)
          QualityPressureSample(t: t, bar: 200 - t * (140 / 2400)),
      ];
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank()]),
        samples: flatProfile(depth: 10),
        pressures: {'t1': series},
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('end pressure above start pressure flags a swap', () {
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(start: 60, end: 200)]),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['startBar'], 60);
      expect(out.single.params['endBar'], 200);
    });

    test('series start 15 bar away from recorded start flags mismatch', () {
      final series = [
        const QualityPressureSample(t: 0, bar: 215),
        const QualityPressureSample(t: 2400, bar: 60),
      ];
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank()]), // recorded start 200
        pressures: {'t1': series},
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['recordBar'], 200);
      expect(out.single.params['seriesBar'], 215);
    });

    test('mid-dive rise away from any switch is flagged', () {
      final series = [
        const QualityPressureSample(t: 0, bar: 200),
        const QualityPressureSample(t: 600, bar: 180),
        const QualityPressureSample(t: 660, bar: 184),
        const QualityPressureSample(t: 720, bar: 188),
        const QualityPressureSample(t: 780, bar: 188.5),
        const QualityPressureSample(t: 2400, bar: 195),
      ];
      // After the drop to 180, pressure rises monotonically to 195: one
      // continuous rising run of 15 bar (180 -> 195), no gas switches.
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(start: 200, end: 195)]),
        pressures: {'t1': series},
      );
      final out = det.detect(ctx);
      expect(out.length, greaterThanOrEqualTo(1));
      expect(out.first.params['riseBar'], closeTo(15.0, 1e-9));
    });

    test('implausible consumption flags SAC', () {
      // 150 bar drop x 12 L over 5 min at avg 10 m (2 atm):
      // 150*12/5/2 = 180 L/min -> flagged.
      final fast = [
        const QualityPressureSample(t: 0, bar: 200),
        const QualityPressureSample(t: 300, bar: 50),
      ];
      final ctx = makeContext(
        dive: makeTestDive(avgDepth: 10, tanks: [tank(end: 50)]),
        samples: flatProfile(depth: 10, durationSeconds: 300),
        pressures: {'t1': fast},
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['surfaceLpm'], closeTo(180.0, 1e-6));
    });
  });
}
