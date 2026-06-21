import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/dive_parser.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

void main() {
  const parser = DiveParser();

  ProfileSample sample({
    required int time,
    required double depth,
    double? temperature,
    double? pressure,
    int? tankIndex,
    int? heartRate,
  }) => ProfileSample(
    timeSeconds: time,
    depth: depth,
    temperature: temperature,
    pressure: pressure,
    tankIndex: tankIndex,
    heartRate: heartRate,
  );

  DownloadedDive diveWith({
    List<ProfileSample> profile = const [],
    List<DownloadedTank> tanks = const [],
  }) => DownloadedDive(
    startTime: DateTime(2024, 6, 15, 8, 30),
    durationSeconds: 3600,
    maxDepth: 30.0,
    profile: profile,
    tanks: tanks,
  );

  group('parseProfile', () {
    test('maps all sample fields including the six O2 sensors', () {
      final dive = diveWith(
        profile: [
          const ProfileSample(
            timeSeconds: 60,
            depth: 12.5,
            temperature: 18.0,
            pressure: 180.0,
            tankIndex: 1,
            heartRate: 85,
            setpoint: 1.3,
            ppo2: 1.28,
            cns: 5.0,
            ndl: 600,
            ceiling: 0.0,
            ascentRate: 8.0,
            rbt: 1200,
            decoType: 0,
            decoTime: 0,
            decoDepth: 0.0,
            tts: 300,
            o2Sensor1: 1.21,
            o2Sensor2: 1.25,
            o2Sensor3: 1.29,
            o2Sensor4: 1.30,
            o2Sensor5: 1.31,
            o2Sensor6: 1.32,
          ),
        ],
      );

      final points = parser.parseProfile(dive);

      expect(points, hasLength(1));
      final p = points.single;
      expect(p.timestamp, 60);
      expect(p.depth, 12.5);
      expect(p.temperature, 18.0);
      expect(p.pressure, 180.0);
      expect(p.tankIndex, 1);
      expect(p.heartRate, 85);
      expect(p.setpoint, 1.3);
      expect(p.ppO2, 1.28);
      expect(p.cns, 5.0);
      expect(p.ndl, 600);
      expect(p.ceiling, 0.0);
      expect(p.ascentRate, 8.0);
      expect(p.rbt, 1200);
      expect(p.decoType, 0);
      expect(p.decoTime, 0);
      expect(p.decoDepth, 0.0);
      expect(p.tts, 300);
      expect(p.o2Sensor1, 1.21);
      expect(p.o2Sensor2, 1.25);
      expect(p.o2Sensor3, 1.29);
      expect(p.o2Sensor4, 1.30);
      expect(p.o2Sensor5, 1.31);
      expect(p.o2Sensor6, 1.32);
    });

    test('passes through null O2 sensors when not present', () {
      final dive = diveWith(profile: [sample(time: 0, depth: 5.0)]);

      final point = parser.parseProfile(dive).single;

      expect(point.o2Sensor1, isNull);
      expect(point.o2Sensor2, isNull);
      expect(point.o2Sensor3, isNull);
      expect(point.o2Sensor4, isNull);
      expect(point.o2Sensor5, isNull);
      expect(point.o2Sensor6, isNull);
    });

    test('preserves order and count of samples', () {
      final dive = diveWith(
        profile: [
          sample(time: 0, depth: 0.0),
          sample(time: 30, depth: 10.0),
          sample(time: 60, depth: 20.0),
        ],
      );

      final points = parser.parseProfile(dive);

      expect(points.map((p) => p.timestamp), [0, 30, 60]);
      expect(points.map((p) => p.depth), [0.0, 10.0, 20.0]);
    });

    test('returns an empty list for a dive without samples', () {
      expect(parser.parseProfile(diveWith()), isEmpty);
    });
  });

  group('parseTanks', () {
    test('maps every tank field', () {
      final dive = diveWith(
        tanks: const [
          DownloadedTank(
            index: 0,
            o2Percent: 32.0,
            hePercent: 0.0,
            startPressure: 200.0,
            endPressure: 50.0,
            volumeLiters: 12.0,
          ),
          DownloadedTank(
            index: 1,
            o2Percent: 21.0,
            hePercent: 35.0,
            startPressure: 230.0,
            endPressure: 80.0,
            volumeLiters: 11.1,
          ),
        ],
      );

      final tanks = parser.parseTanks(dive);

      expect(tanks, hasLength(2));
      expect(tanks[0].index, 0);
      expect(tanks[0].o2Percent, 32.0);
      expect(tanks[0].hePercent, 0.0);
      expect(tanks[0].startPressure, 200.0);
      expect(tanks[0].endPressure, 50.0);
      expect(tanks[0].volumeLiters, 12.0);
      expect(tanks[1].index, 1);
      expect(tanks[1].hePercent, 35.0);
    });

    test('returns an empty list for a dive without tanks', () {
      expect(parser.parseTanks(diveWith()), isEmpty);
    });
  });

  group('calculateMaxDepth', () {
    test('returns the deepest sample', () {
      final profile = [
        sample(time: 0, depth: 5.0),
        sample(time: 30, depth: 22.5),
        sample(time: 60, depth: 18.0),
      ];
      expect(parser.calculateMaxDepth(profile), 22.5);
    });

    test('returns 0 for an empty profile', () {
      expect(parser.calculateMaxDepth(const []), 0.0);
    });
  });

  group('calculateAvgDepth', () {
    test('weights depth by time interval', () {
      // 10m for 60s, then 20m for 60s, last sample assumed 1s at 20m.
      final profile = [
        sample(time: 0, depth: 10.0),
        sample(time: 60, depth: 20.0),
        sample(time: 120, depth: 20.0),
      ];

      // (10*60 + 20*60 + 20*1) / (60 + 60 + 1) = 1820 / 121
      expect(parser.calculateAvgDepth(profile), closeTo(1820 / 121, 1e-9));
    });

    test('returns 0 for an empty profile', () {
      expect(parser.calculateAvgDepth(const []), 0.0);
    });

    test('handles a single sample', () {
      expect(parser.calculateAvgDepth([sample(time: 0, depth: 15.0)]), 15.0);
    });
  });

  group('extractTemperatureRange', () {
    test('returns min and max of available temperatures', () {
      final profile = [
        sample(time: 0, depth: 5.0, temperature: 20.0),
        sample(time: 30, depth: 15.0, temperature: 14.0),
        sample(time: 60, depth: 10.0, temperature: 17.0),
      ];

      final range = parser.extractTemperatureRange(profile);

      expect(range.min, 14.0);
      expect(range.max, 20.0);
    });

    test('ignores samples without temperature', () {
      final profile = [
        sample(time: 0, depth: 5.0),
        sample(time: 30, depth: 15.0, temperature: 12.0),
      ];

      final range = parser.extractTemperatureRange(profile);

      expect(range.min, 12.0);
      expect(range.max, 12.0);
    });

    test('returns nulls when no temperatures are present', () {
      final range = parser.extractTemperatureRange([
        sample(time: 0, depth: 5.0),
      ]);

      expect(range.min, isNull);
      expect(range.max, isNull);
    });
  });

  group('detectSafetyStop', () {
    test('detects a safety stop held at ~5m before surfacing', () {
      final profile = <ProfileSample>[
        sample(time: 0, depth: 0.0),
        sample(time: 60, depth: 20.0),
        // Safety stop window: 5m from 120s to 300s (180s > 120s minimum).
        sample(time: 120, depth: 5.0),
        sample(time: 180, depth: 5.0),
        sample(time: 240, depth: 5.0),
        sample(time: 300, depth: 5.0),
        // Surface afterwards.
        sample(time: 360, depth: 0.0),
      ];

      final stop = parser.detectSafetyStop(profile);

      expect(stop, isNotNull);
      expect(stop!.startTime, 120);
      expect(stop.duration, greaterThanOrEqualTo(120));
      expect(stop.depth, 5.0);
    });

    test('returns null when the stop is too short', () {
      final profile = <ProfileSample>[
        sample(time: 0, depth: 0.0),
        sample(time: 60, depth: 20.0),
        sample(time: 120, depth: 5.0),
        sample(time: 160, depth: 5.0), // only 40s at 5m
        sample(time: 220, depth: 0.0),
      ];

      expect(parser.detectSafetyStop(profile), isNull);
    });

    test('returns null when there is no shallow stop', () {
      final profile = <ProfileSample>[
        sample(time: 0, depth: 0.0),
        sample(time: 60, depth: 25.0),
        sample(time: 120, depth: 25.0),
        sample(time: 180, depth: 0.0),
      ];

      expect(parser.detectSafetyStop(profile), isNull);
    });
  });

  group('calculateAscentRates', () {
    test('reports rate and severity for ascending segments only', () {
      final profile = <ProfileSample>[
        sample(time: 0, depth: 30.0),
        // Descending segment is ignored.
        sample(time: 30, depth: 32.0),
        // Ascend 5m in 60s -> 5 m/min (safe).
        sample(time: 90, depth: 27.0),
        // Ascend 15m in 60s -> 15 m/min (critical).
        sample(time: 150, depth: 12.0),
      ];

      final rates = parser.calculateAscentRates(profile);

      expect(rates, hasLength(2));
      expect(rates[0].rateMetersPerMin, closeTo(5.0, 1e-9));
      expect(rates[0].severity, AscentRateSeverity.safe);
      expect(rates[1].rateMetersPerMin, closeTo(15.0, 1e-9));
      expect(rates[1].severity, AscentRateSeverity.critical);
    });

    test('classifies the warning band (9-12 m/min)', () {
      final profile = <ProfileSample>[
        sample(time: 0, depth: 20.0),
        sample(time: 60, depth: 10.0), // 10 m/min
      ];

      final rates = parser.calculateAscentRates(profile);

      expect(rates, hasLength(1));
      expect(rates.single.severity, AscentRateSeverity.warning);
    });

    test('returns empty when there is no ascent', () {
      final profile = <ProfileSample>[
        sample(time: 0, depth: 5.0),
        sample(time: 60, depth: 20.0),
      ];

      expect(parser.calculateAscentRates(profile), isEmpty);
    });
  });

  group('analyzeDivePhases', () {
    test('identifies descent end, ascent start and bottom time', () {
      // Max depth (30m) is first reached at t=90. descentEnd is the first
      // sample within 10% of max (>=27m) before that: t=60. ascentStart is the
      // last sample within 10% of max: t=150.
      final profile = <ProfileSample>[
        sample(time: 0, depth: 0.0),
        sample(time: 30, depth: 15.0),
        sample(time: 60, depth: 28.0),
        sample(time: 90, depth: 30.0),
        sample(time: 120, depth: 30.0),
        sample(time: 150, depth: 30.0),
        sample(time: 180, depth: 10.0),
        sample(time: 240, depth: 0.0),
      ];

      final phases = parser.analyzeDivePhases(profile);

      expect(phases.descentEnd, 60);
      expect(phases.ascentStart, 150);
      expect(phases.bottomTime, 90);
    });

    test('returns zeroed phases for an empty profile', () {
      final phases = parser.analyzeDivePhases(const []);

      expect(phases.descentEnd, 0);
      expect(phases.ascentStart, 0);
      expect(phases.bottomTime, 0);
    });
  });
}
