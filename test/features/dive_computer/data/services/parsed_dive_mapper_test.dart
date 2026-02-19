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
            heartRate: 85.0,
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
  });
}
