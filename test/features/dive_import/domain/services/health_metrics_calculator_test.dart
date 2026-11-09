import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/domain/entities/health_sample.dart';
import 'package:submersion/features/dive_import/domain/services/health_metrics_calculator.dart';

/// Turns raw Apple Health samples into a dive's heart rate, recovery and
/// sleep readings (issue #637).
void main() {
  DateTime at(int day, int hour, [int minute = 0, int second = 0]) =>
      DateTime.utc(2026, 7, day, hour, minute, second);
  HealthSample hr(DateTime when, double bpm) =>
      HealthSample(at: when, value: bpm);
  SleepInterval asleep(DateTime start, DateTime end) =>
      SleepInterval(start: start, end: end);

  group('summarizeHeartRate', () {
    test('rounds the average and keeps the maximum', () {
      final summary = summarizeHeartRate([
        hr(at(17, 10), 60),
        hr(at(17, 10, 1), 61),
        hr(at(17, 10, 2), 62),
      ])!;

      expect(summary.average, 61);
      expect(summary.maximum, 62);
    });

    test('is null with no samples', () {
      expect(summarizeHeartRate(const []), isNull);
    });
  });

  group('recoveryAfter', () {
    final exit = at(17, 10, 45);

    test('picks the nearest sample within two minutes of each moment', () {
      final readings = recoveryAfter([
        hr(at(17, 10, 44, 30), 90),
        hr(at(17, 10, 46), 88),
        hr(at(17, 10, 50, 40), 75),
        hr(at(17, 10, 51, 30), 70),
        hr(at(17, 11), 65),
      ], exit);

      expect(readings.atExit, 90);
      expect(readings.plus5, 75);
      expect(readings.plus15, 65);
    });

    test('leaves a moment empty when no sample is near it', () {
      final readings = recoveryAfter([
        hr(exit, 92),
        hr(at(17, 10, 53, 30), 71),
      ], exit);

      expect(readings.atExit, 92);
      expect(readings.plus5, isNull);
      expect(readings.plus15, isNull);
    });
  });

  group('overnightHrv', () {
    test('averages the night after the dive, skipping a nap', () {
      final hrv = [
        hr(at(17, 13, 20), 80),
        hr(at(17, 23), 40),
        hr(at(18, 3), 50),
        hr(at(18, 7, 30), 90),
      ];
      final sleep = [
        asleep(at(17, 13), at(17, 13, 40)),
        asleep(at(17, 22, 30), at(18, 2)),
        asleep(at(18, 2, 20), at(18, 6, 30)),
      ];

      expect(overnightHrv(hrv, sleep, at(17, 10, 45)), 45);
    });

    test('is null when no night starts within 18 hours', () {
      final sleep = [asleep(at(18, 6), at(18, 12))];

      expect(overnightHrv([hr(at(18, 7), 50)], sleep, at(17, 10, 45)), isNull);
    });
  });

  group('sleepBeforeMinutes', () {
    test('counts only sleep from 18:00 the evening before', () {
      final sleep = [
        asleep(at(16, 15), at(16, 16)),
        asleep(at(16, 17, 40), at(16, 18, 10)),
        asleep(at(16, 23), at(17, 3)),
        asleep(at(17, 3, 30), at(17, 6, 30)),
      ];

      expect(sleepBeforeMinutes(sleep, at(17, 9)), 10 + 240 + 180);
    });

    test('is null with no sleep in the window', () {
      expect(
        sleepBeforeMinutes([asleep(at(16, 13), at(16, 14))], at(17, 9)),
        isNull,
      );
    });
  });

  test('heart rate offsets are whole seconds from the entry', () {
    final entry = at(17, 10);

    expect(
      heartRateOffsets([
        hr(at(17, 10, 1), 76.6),
        hr(at(17, 9, 59), 99),
        hr(entry, 82.4),
      ], entry),
      [
        [0, 82],
        [60, 77],
      ],
    );
  });
}
