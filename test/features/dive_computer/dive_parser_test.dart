import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/dive_parser.dart';
import 'package:submersion/features/dive_computer/domain/services/download_manager.dart';

void main() {
  const parser = DiveParser();

  group('DiveParser', () {
    group('parseProfile', () {
      test('converts profile samples to ProfilePointData', () {
        final downloadedDive = DownloadedDive(
          diveNumber: 1,
          startTime: DateTime(2024, 6, 15, 10, 30),
          durationSeconds: 600,
          maxDepth: 20.0,
          avgDepth: 15.0,
          profile: const [
            ProfileSample(timeSeconds: 0, depth: 0.0),
            ProfileSample(timeSeconds: 60, depth: 10.0),
            ProfileSample(timeSeconds: 120, depth: 20.0),
          ],
          tanks: const [],
          fingerprint: 'test',
        );

        final result = parser.parseProfile(downloadedDive);

        expect(result, hasLength(3));
        expect(result[0].depth, equals(0.0));
        expect(result[1].depth, equals(10.0));
        expect(result[2].depth, equals(20.0));
      });

      test('includes temperature when present', () {
        final downloadedDive = DownloadedDive(
          diveNumber: 1,
          startTime: DateTime(2024, 6, 15, 10, 30),
          durationSeconds: 120,
          maxDepth: 10.0,
          avgDepth: 8.0,
          profile: const [
            ProfileSample(timeSeconds: 0, depth: 0.0, temperature: 22.0),
            ProfileSample(timeSeconds: 60, depth: 10.0, temperature: 20.0),
            ProfileSample(timeSeconds: 120, depth: 0.0, temperature: 22.0),
          ],
          tanks: const [],
          fingerprint: 'test',
        );

        final result = parser.parseProfile(downloadedDive);

        expect(result[0].temperature, equals(22.0));
        expect(result[1].temperature, equals(20.0));
        expect(result[2].temperature, equals(22.0));
      });

      test('includes pressure when present', () {
        final downloadedDive = DownloadedDive(
          diveNumber: 1,
          startTime: DateTime(2024, 6, 15, 10, 30),
          durationSeconds: 120,
          maxDepth: 10.0,
          avgDepth: 8.0,
          profile: const [
            ProfileSample(timeSeconds: 0, depth: 0.0, pressure: 200.0),
            ProfileSample(timeSeconds: 60, depth: 10.0, pressure: 150.0),
            ProfileSample(timeSeconds: 120, depth: 0.0, pressure: 100.0),
          ],
          tanks: const [],
          fingerprint: 'test',
        );

        final result = parser.parseProfile(downloadedDive);

        expect(result[0].pressure, equals(200.0));
        expect(result[1].pressure, equals(150.0));
        expect(result[2].pressure, equals(100.0));
      });

      test('stores relative timestamps in seconds from dive start', () {
        final startTime = DateTime(2024, 6, 15, 10, 30);
        final downloadedDive = DownloadedDive(
          diveNumber: 1,
          startTime: startTime,
          durationSeconds: 120,
          maxDepth: 10.0,
          avgDepth: 8.0,
          profile: const [
            ProfileSample(timeSeconds: 0, depth: 0.0),
            ProfileSample(timeSeconds: 60, depth: 10.0),
            ProfileSample(timeSeconds: 120, depth: 0.0),
          ],
          tanks: const [],
          fingerprint: 'test',
        );

        final result = parser.parseProfile(downloadedDive);

        // Timestamps are stored as relative seconds from dive start
        // (not absolute milliseconds) per dive_parser.dart documentation
        expect(result[0].timestamp, equals(0));
        expect(result[1].timestamp, equals(60));
        expect(result[2].timestamp, equals(120));
      });
    });

    group('calculateMaxDepth', () {
      test('returns maximum depth from profile', () {
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 0.0),
          ProfileSample(timeSeconds: 60, depth: 10.0),
          ProfileSample(timeSeconds: 120, depth: 25.0),
          ProfileSample(timeSeconds: 180, depth: 20.0),
          ProfileSample(timeSeconds: 240, depth: 5.0),
        ];

        final maxDepth = parser.calculateMaxDepth(profile);

        expect(maxDepth, equals(25.0));
      });

      test('returns 0 for empty profile', () {
        final maxDepth = parser.calculateMaxDepth([]);

        expect(maxDepth, equals(0.0));
      });
    });

    group('calculateAvgDepth', () {
      test('calculates weighted average depth', () {
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 10.0),
          ProfileSample(timeSeconds: 60, depth: 20.0),
          ProfileSample(timeSeconds: 120, depth: 20.0),
          ProfileSample(timeSeconds: 180, depth: 10.0),
        ];

        final avgDepth = parser.calculateAvgDepth(profile);

        // Average should be weighted by time intervals
        expect(avgDepth, greaterThan(10.0));
        expect(avgDepth, lessThan(20.0));
      });

      test('returns 0 for empty profile', () {
        final avgDepth = parser.calculateAvgDepth([]);

        expect(avgDepth, equals(0.0));
      });
    });

    group('extractTemperatureRange', () {
      test('returns min and max temperature', () {
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 0.0, temperature: 22.0),
          ProfileSample(timeSeconds: 60, depth: 10.0, temperature: 18.0),
          ProfileSample(timeSeconds: 120, depth: 20.0, temperature: 15.0),
          ProfileSample(timeSeconds: 180, depth: 10.0, temperature: 19.0),
        ];

        final range = parser.extractTemperatureRange(profile);

        expect(range.min, equals(15.0));
        expect(range.max, equals(22.0));
      });

      test('returns null for profile without temperature', () {
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 0.0),
          ProfileSample(timeSeconds: 60, depth: 10.0),
        ];

        final range = parser.extractTemperatureRange(profile);

        expect(range.min, isNull);
        expect(range.max, isNull);
      });
    });

    group('detectSafetyStop', () {
      test('detects safety stop at 5m for 3 minutes', () {
        const profile = [
          // Descent and bottom
          ProfileSample(timeSeconds: 0, depth: 0.0),
          ProfileSample(timeSeconds: 60, depth: 10.0),
          ProfileSample(timeSeconds: 120, depth: 20.0),
          ProfileSample(timeSeconds: 600, depth: 20.0),
          // Ascent
          ProfileSample(timeSeconds: 660, depth: 15.0),
          ProfileSample(timeSeconds: 720, depth: 10.0),
          // Safety stop at 5m for 3 minutes
          ProfileSample(timeSeconds: 780, depth: 5.0),
          ProfileSample(timeSeconds: 840, depth: 5.0),
          ProfileSample(timeSeconds: 900, depth: 5.0),
          ProfileSample(timeSeconds: 960, depth: 5.0),
          // Final ascent
          ProfileSample(timeSeconds: 1020, depth: 3.0),
          ProfileSample(timeSeconds: 1080, depth: 0.0),
        ];

        final safetyStop = parser.detectSafetyStop(profile);

        expect(safetyStop, isNotNull);
        expect(safetyStop!.depth, closeTo(5.0, 1.0));
        expect(safetyStop.duration, greaterThanOrEqualTo(120));
      });

      test('returns null for dive without safety stop', () {
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 10.0),
          ProfileSample(timeSeconds: 60, depth: 8.0),
          ProfileSample(timeSeconds: 120, depth: 6.0),
          ProfileSample(timeSeconds: 180, depth: 4.0),
          ProfileSample(timeSeconds: 240, depth: 2.0),
          ProfileSample(timeSeconds: 300, depth: 0.0),
        ];

        final safetyStop = parser.detectSafetyStop(profile);

        expect(safetyStop, isNull);
      });
    });

    group('calculateAscentRates', () {
      test('calculates correct ascent rate', () {
        // 10m in 60 seconds = 10m/min
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 20.0),
          ProfileSample(timeSeconds: 60, depth: 10.0),
        ];

        final rates = parser.calculateAscentRates(profile);

        expect(rates, hasLength(1));
        expect(rates[0].rateMetersPerMin, closeTo(10.0, 0.1));
      });

      test('only calculates for ascending segments', () {
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 10.0),
          ProfileSample(timeSeconds: 60, depth: 20.0), // Descending - no rate
          ProfileSample(timeSeconds: 120, depth: 10.0), // Ascending - has rate
        ];

        final rates = parser.calculateAscentRates(profile);

        // Only one ascending segment
        expect(rates, hasLength(1));
        expect(rates[0].rateMetersPerMin, closeTo(10.0, 0.1));
      });

      test('includes severity classification', () {
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 20.0),
          ProfileSample(timeSeconds: 60, depth: 12.0), // 8 m/min - safe
          ProfileSample(timeSeconds: 120, depth: 2.0), // 10 m/min - warning
        ];

        final rates = parser.calculateAscentRates(profile);

        expect(rates[0].severity, equals(AscentRateSeverity.safe));
        expect(rates[1].severity, equals(AscentRateSeverity.warning));
      });
    });

    group('analyzeDivePhases', () {
      test('detects descent end time', () {
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 0.0),
          ProfileSample(timeSeconds: 30, depth: 5.0),
          ProfileSample(timeSeconds: 60, depth: 10.0),
          ProfileSample(timeSeconds: 90, depth: 18.0), // Near max
          ProfileSample(timeSeconds: 120, depth: 20.0), // Max
          ProfileSample(timeSeconds: 300, depth: 20.0),
          ProfileSample(timeSeconds: 360, depth: 10.0),
          ProfileSample(timeSeconds: 420, depth: 0.0),
        ];

        final phases = parser.analyzeDivePhases(profile);

        expect(phases.descentEnd, equals(90)); // When 90% of max was reached
      });

      test('detects ascent start time', () {
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 0.0),
          ProfileSample(timeSeconds: 60, depth: 20.0),
          ProfileSample(timeSeconds: 300, depth: 18.0), // Still near max
          ProfileSample(timeSeconds: 360, depth: 10.0), // Clearly ascending
          ProfileSample(timeSeconds: 420, depth: 0.0),
        ];

        final phases = parser.analyzeDivePhases(profile);

        expect(phases.ascentStart, equals(300)); // Last point near max
      });

      test('calculates bottom time', () {
        const profile = [
          ProfileSample(timeSeconds: 0, depth: 0.0),
          ProfileSample(timeSeconds: 60, depth: 19.0), // Near max
          ProfileSample(timeSeconds: 120, depth: 20.0),
          ProfileSample(timeSeconds: 300, depth: 19.0), // Near max
          ProfileSample(timeSeconds: 360, depth: 10.0),
          ProfileSample(timeSeconds: 420, depth: 0.0),
        ];

        final phases = parser.analyzeDivePhases(profile);

        expect(phases.bottomTime, greaterThan(0));
      });

      test('handles empty profile', () {
        final phases = parser.analyzeDivePhases([]);

        expect(phases.descentEnd, equals(0));
        expect(phases.ascentStart, equals(0));
        expect(phases.bottomTime, equals(0));
      });
    });
  });

  group('SafetyStopInfo', () {
    test('holds safety stop data', () {
      const info = SafetyStopInfo(startTime: 600, duration: 180, depth: 5.0);

      expect(info.startTime, equals(600));
      expect(info.duration, equals(180));
      expect(info.depth, equals(5.0));
    });
  });

  group('AscentRateInfo', () {
    test('holds ascent rate data', () {
      const info = AscentRateInfo(
        timeSeconds: 300,
        depth: 10.0,
        rateMetersPerMin: 9.0,
        severity: AscentRateSeverity.safe,
      );

      expect(info.timeSeconds, equals(300));
      expect(info.depth, equals(10.0));
      expect(info.rateMetersPerMin, equals(9.0));
      expect(info.severity, equals(AscentRateSeverity.safe));
    });
  });

  group('AscentRateSeverity', () {
    test('has correct values', () {
      expect(AscentRateSeverity.values, hasLength(3));
      expect(AscentRateSeverity.safe.index, equals(0));
      expect(AscentRateSeverity.warning.index, equals(1));
      expect(AscentRateSeverity.critical.index, equals(2));
    });
  });

  group('DivePhases', () {
    test('holds phase timing data', () {
      const phases = DivePhases(
        descentEnd: 120,
        ascentStart: 1800,
        bottomTime: 1680,
      );

      expect(phases.descentEnd, equals(120));
      expect(phases.ascentStart, equals(1800));
      expect(phases.bottomTime, equals(1680));
    });
  });

  group('DownloadedDive', () {
    test('can be created with minimal data', () {
      final dive = DownloadedDive(
        diveNumber: 1,
        startTime: DateTime.now(),
        durationSeconds: 3600,
        maxDepth: 20.0,
        avgDepth: 15.0,
        profile: const [],
        tanks: const [],
        fingerprint: 'test',
      );

      expect(dive.diveNumber, equals(1));
      expect(dive.maxDepth, equals(20.0));
    });
  });

  group('ProfileSample', () {
    test('can be created with all data', () {
      const sample = ProfileSample(
        timeSeconds: 300,
        depth: 20.0,
        temperature: 18.5,
        pressure: 150.0,
        tankIndex: 0,
        ndl: 15,
        ceiling: 0.0,
      );

      expect(sample.timeSeconds, equals(300));
      expect(sample.depth, equals(20.0));
      expect(sample.temperature, equals(18.5));
      expect(sample.pressure, equals(150.0));
      expect(sample.ndl, equals(15));
    });

    test('can be created with minimal data', () {
      const sample = ProfileSample(timeSeconds: 60, depth: 10.0);

      expect(sample.timeSeconds, equals(60));
      expect(sample.depth, equals(10.0));
      expect(sample.temperature, isNull);
      expect(sample.pressure, isNull);
    });
  });

  group('DownloadedTank', () {
    test('holds tank data', () {
      const tank = DownloadedTank(
        index: 0,
        o2Percent: 32.0,
        hePercent: 0.0,
        startPressure: 200.0,
        endPressure: 50.0,
        volumeLiters: 12.0,
      );

      expect(tank.index, equals(0));
      expect(tank.o2Percent, equals(32.0));
      expect(tank.hePercent, equals(0.0));
      expect(tank.startPressure, equals(200.0));
      expect(tank.endPressure, equals(50.0));
      expect(tank.volumeLiters, equals(12.0));
    });
  });
}
