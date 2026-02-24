import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_dive_mapper.dart';

void main() {
  group('parsedDiveToDownloaded', () {
    test('converts basic ParsedDive to DownloadedDive', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'abc123',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 30.0,
        avgDepthMeters: 15.5,
        durationSeconds: 3600,
        minTemperatureCelsius: 18.0,
        maxTemperatureCelsius: 22.0,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.fingerprint, 'abc123');
      expect(downloaded.maxDepth, 30.0);
      expect(downloaded.avgDepth, 15.5);
      expect(downloaded.durationSeconds, 3600);
      expect(downloaded.minTemperature, 18.0);
      expect(downloaded.maxTemperature, 22.0);
      expect(
        downloaded.startTime,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );
    });

    test('maps profile samples correctly', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'def456',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 25.0,
        avgDepthMeters: 12.0,
        durationSeconds: 2400,
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 10.0,
            temperatureCelsius: 20.0,
            pressureBar: 195.0,
            tankIndex: 0,
          ),
          pigeon.ProfileSample(
            timeSeconds: 120,
            depthMeters: 25.0,
            temperatureCelsius: 18.5,
            heartRate: 85,
          ),
        ],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.profile, hasLength(3));

      expect(downloaded.profile[0].timeSeconds, 0);
      expect(downloaded.profile[0].depth, 0.0);
      expect(downloaded.profile[0].temperature, isNull);

      expect(downloaded.profile[1].timeSeconds, 60);
      expect(downloaded.profile[1].depth, 10.0);
      expect(downloaded.profile[1].temperature, 20.0);
      expect(downloaded.profile[1].pressure, 195.0);
      expect(downloaded.profile[1].tankIndex, 0);

      expect(downloaded.profile[2].heartRate, 85);
    });

    test('maps tanks with gas mixes correctly', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'ghi789',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 40.0,
        avgDepthMeters: 20.0,
        durationSeconds: 3000,
        samples: [],
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            startPressureBar: 200.0,
            endPressureBar: 50.0,
            volumeLiters: 12.0,
          ),
          pigeon.TankInfo(
            index: 1,
            gasMixIndex: 1,
            startPressureBar: 200.0,
            endPressureBar: 120.0,
          ),
        ],
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
        ],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.tanks, hasLength(2));

      expect(downloaded.tanks[0].index, 0);
      expect(downloaded.tanks[0].o2Percent, 32.0);
      expect(downloaded.tanks[0].hePercent, 0.0);
      expect(downloaded.tanks[0].startPressure, 200.0);
      expect(downloaded.tanks[0].endPressure, 50.0);
      expect(downloaded.tanks[0].volumeLiters, 12.0);
      expect(downloaded.tanks[0].isNitrox, isTrue);

      expect(downloaded.tanks[1].index, 1);
      expect(downloaded.tanks[1].o2Percent, 50.0);
      expect(downloaded.tanks[1].gasName, 'EAN50');
    });

    test('falls back to air when gas mix not found', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'fallback',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 20.0,
        avgDepthMeters: 10.0,
        durationSeconds: 1800,
        samples: [],
        tanks: [pigeon.TankInfo(index: 0, gasMixIndex: 99)],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.tanks, hasLength(1));
      expect(downloaded.tanks[0].o2Percent, 21.0);
      expect(downloaded.tanks[0].hePercent, 0.0);
      expect(downloaded.tanks[0].isAir, isTrue);
    });

    test('handles trimix gas', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'trimix',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 60.0,
        avgDepthMeters: 35.0,
        durationSeconds: 4800,
        samples: [],
        tanks: [pigeon.TankInfo(index: 0, gasMixIndex: 0)],
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 18.0, hePercent: 45.0)],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.tanks[0].o2Percent, 18.0);
      expect(downloaded.tanks[0].hePercent, 45.0);
      expect(downloaded.tanks[0].isTrimix, isTrue);
      expect(downloaded.tanks[0].gasName, 'TMX 18/45');
    });

    test('handles null optional fields', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'minimal',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 10.0,
        avgDepthMeters: 5.0,
        durationSeconds: 600,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.minTemperature, isNull);
      expect(downloaded.maxTemperature, isNull);
      expect(downloaded.profile, isEmpty);
      expect(downloaded.tanks, isEmpty);
    });

    test('maps all new sample fields when populated', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'all-fields',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 40.0,
        avgDepthMeters: 25.0,
        durationSeconds: 3600,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 300,
            depthMeters: 35.0,
            temperatureCelsius: 16.0,
            pressureBar: 180.0,
            tankIndex: 0,
            heartRate: 92,
            setpoint: 1.3,
            ppo2: 1.28,
            cns: 15.5,
            rbt: 45,
            decoType: 2,
            decoTime: 180,
            decoDepth: 6.0,
            tts: 420,
          ),
        ],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.timeSeconds, 300);
      expect(sample.depth, 35.0);
      expect(sample.temperature, 16.0);
      expect(sample.pressure, 180.0);
      expect(sample.tankIndex, 0);
      expect(sample.heartRate, 92);
      expect(sample.setpoint, 1.3);
      expect(sample.ppo2, 1.28);
      expect(sample.cns, 15.5);
      expect(sample.rbt, 45);
      expect(sample.decoType, 2);
      expect(sample.decoTime, 180);
      expect(sample.decoDepth, 6.0);
      expect(sample.tts, 420);
    });

    test('maps null/missing new sample fields correctly', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'null-fields',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 20.0,
        avgDepthMeters: 10.0,
        durationSeconds: 1800,
        samples: [pigeon.ProfileSample(timeSeconds: 60, depthMeters: 15.0)],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.setpoint, isNull);
      expect(sample.ppo2, isNull);
      expect(sample.cns, isNull);
      expect(sample.rbt, isNull);
      expect(sample.decoType, isNull);
      expect(sample.decoTime, isNull);
      expect(sample.decoDepth, isNull);
      expect(sample.tts, isNull);
      expect(sample.ndl, isNull);
      expect(sample.ceiling, isNull);
    });

    test('derives NDL from decoTime when decoType is 0 (NDL mode)', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'ndl-derive',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 20.0,
        avgDepthMeters: 15.0,
        durationSeconds: 1800,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 18.0,
            decoType: 0,
            decoTime: 720,
          ),
        ],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.ndl, 720);
      expect(sample.ceiling, isNull);
    });

    test('derives ceiling from decoDepth when decoType is deco mode', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'ceiling-derive',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 45.0,
        avgDepthMeters: 30.0,
        durationSeconds: 3600,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 300,
            depthMeters: 40.0,
            decoType: 2,
            decoTime: 180,
            decoDepth: 6.0,
          ),
        ],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.ceiling, 6.0);
      expect(sample.ndl, isNull);
    });

    test('derives ceiling from decoDepth when decoType is safety stop (1)', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'ceiling-safety',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 30.0,
        avgDepthMeters: 20.0,
        durationSeconds: 2400,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 300,
            depthMeters: 5.0,
            decoType: 1,
            decoTime: 180,
            decoDepth: 5.0,
          ),
        ],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.ceiling, 5.0);
      expect(sample.ndl, isNull);
    });

    test('derives ceiling from decoDepth when decoType is deep stop (3)', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'ceiling-deep',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 50.0,
        avgDepthMeters: 35.0,
        durationSeconds: 3600,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 600,
            depthMeters: 30.0,
            decoType: 3,
            decoTime: 120,
            decoDepth: 18.0,
          ),
        ],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.ceiling, 18.0);
      expect(sample.ndl, isNull);
    });

    test('does not derive ceiling for NDL mode (decoType 0)', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'no-ceiling-ndl',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 20.0,
        avgDepthMeters: 10.0,
        durationSeconds: 1800,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 15.0,
            decoType: 0,
            decoTime: 900,
            decoDepth: 0.0,
          ),
        ],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.ndl, 900);
      expect(sample.ceiling, isNull);
    });

    test('maps deco model fields correctly', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'deco-model',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 50.0,
        avgDepthMeters: 30.0,
        durationSeconds: 3600,
        decoAlgorithm: 'buhlmann',
        gfLow: 30,
        gfHigh: 70,
        decoConservatism: 2,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.decoAlgorithm, 'buhlmann');
      expect(downloaded.gfLow, 30);
      expect(downloaded.gfHigh, 70);
      expect(downloaded.decoConservatism, 2);
    });

    test('maps null deco model fields correctly', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'no-deco-model',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 20.0,
        avgDepthMeters: 10.0,
        durationSeconds: 1800,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.decoAlgorithm, isNull);
      expect(downloaded.gfLow, isNull);
      expect(downloaded.gfHigh, isNull);
      expect(downloaded.decoConservatism, isNull);
    });

    test('maps events with flags and value from data map', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'events-test',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 30.0,
        avgDepthMeters: 20.0,
        durationSeconds: 2400,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [
          pigeon.DiveEvent(
            timeSeconds: 120,
            type: 'gaschange',
            data: {'flags': '1', 'value': '32'},
          ),
          pigeon.DiveEvent(
            timeSeconds: 600,
            type: 'deco',
            data: {'flags': '0', 'value': '180'},
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.events, hasLength(2));

      expect(downloaded.events[0].timeSeconds, 120);
      expect(downloaded.events[0].type, 'gaschange');
      expect(downloaded.events[0].flags, 1);
      expect(downloaded.events[0].value, 32);

      expect(downloaded.events[1].timeSeconds, 600);
      expect(downloaded.events[1].type, 'deco');
      expect(downloaded.events[1].flags, 0);
      expect(downloaded.events[1].value, 180);
    });

    test('maps events with null data map', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'events-null-data',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 30.0,
        avgDepthMeters: 20.0,
        durationSeconds: 2400,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [pigeon.DiveEvent(timeSeconds: 300, type: 'heading')],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.events, hasLength(1));
      expect(downloaded.events[0].timeSeconds, 300);
      expect(downloaded.events[0].type, 'heading');
      expect(downloaded.events[0].flags, isNull);
      expect(downloaded.events[0].value, isNull);
    });

    test('maps empty events list to empty DownloadedEvent list', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'no-events',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 20.0,
        avgDepthMeters: 10.0,
        durationSeconds: 1800,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.events, isEmpty);
    });
  });
}
