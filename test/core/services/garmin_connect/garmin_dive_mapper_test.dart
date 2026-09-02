import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/garmin_connect/garmin_dive_mapper.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';

ImportedDive _dive({
  List<ImportedTank> tanks = const [],
  List<ImportedGasSwitch> gasSwitches = const [],
  List<ImportedProfileSample> profile = const [],
  int? gfLow,
  int? gfHigh,
  String? decoModel,
  double? latitude = 10.0,
  double? longitude = 20.0,
}) {
  return ImportedDive(
    sourceId: 'garmin-1',
    source: ImportSource.garmin,
    startTime: DateTime.utc(2026, 3, 15, 10, 0),
    endTime: DateTime.utc(2026, 3, 15, 10, 30),
    maxDepth: 18.5,
    avgDepth: 10.2,
    minTemperature: 22.0,
    maxTemperature: 25.0,
    latitude: latitude,
    longitude: longitude,
    exitLatitude: 10.1,
    exitLongitude: 20.1,
    computerModel: 'Descent Mk2',
    computerSerial: 'SN-42',
    computerFirmware: '5.10',
    gfLow: gfLow,
    gfHigh: gfHigh,
    decoModel: decoModel,
    tanks: tanks,
    gasSwitches: gasSwitches,
    profile: profile,
  );
}

void main() {
  group('GarminDiveMapper.map', () {
    test('maps header fields and device identity', () {
      final result = GarminDiveMapper.map(_dive(), activityId: 123);

      expect(result.dive.startTime, DateTime.utc(2026, 3, 15, 10, 0));
      expect(result.dive.durationSeconds, 1800);
      expect(result.dive.maxDepth, 18.5);
      expect(result.dive.avgDepth, 10.2);
      expect(result.dive.minTemperature, 22.0);
      expect(result.dive.maxTemperature, 25.0);
      expect(result.dive.entryLatitude, 10.0);
      expect(result.dive.entryLongitude, 20.0);
      expect(result.dive.exitLatitude, 10.1);
      expect(result.dive.exitLongitude, 20.1);

      expect(result.deviceModel, 'Descent Mk2');
      expect(result.serialNumber, 'SN-42');
      expect(result.firmwareVersion, '5.10');
    });

    test('falls back to Connect\'s activity-list position when the FIT file '
        'has none', () {
      final result = GarminDiveMapper.map(
        _dive(latitude: null, longitude: null),
        activityId: 1,
        fallbackLatitude: 28.4594,
        fallbackLongitude: -16.3228,
      );

      expect(result.dive.entryLatitude, 28.4594);
      expect(result.dive.entryLongitude, -16.3228);
    });

    test('prefers the FIT file\'s own position over the fallback', () {
      final result = GarminDiveMapper.map(
        _dive(),
        activityId: 1,
        fallbackLatitude: 99.0,
        fallbackLongitude: 99.0,
      );

      expect(result.dive.entryLatitude, 10.0);
      expect(result.dive.entryLongitude, 20.0);
    });

    test('ignores a lone fallback latitude with no matching longitude, rather '
        'than pairing it with a stale value', () {
      final result = GarminDiveMapper.map(
        _dive(latitude: null, longitude: null),
        activityId: 1,
        fallbackLatitude: 28.4594,
      );

      expect(result.dive.entryLatitude, isNull);
      expect(result.dive.entryLongitude, isNull);
    });

    test('produces a stable, distinct fingerprint per activity id', () {
      final a = GarminDiveMapper.map(_dive(), activityId: 111);
      final aAgain = GarminDiveMapper.map(_dive(), activityId: 111);
      final b = GarminDiveMapper.map(_dive(), activityId: 222);

      expect(a.dive.rawFingerprint, isNotNull);
      expect(a.dive.rawFingerprint, aAgain.dive.rawFingerprint);
      expect(a.dive.rawFingerprint, isNot(b.dive.rawFingerprint));
    });

    test('carries gradient factors and deco model when present', () {
      final result = GarminDiveMapper.map(
        _dive(gfLow: 30, gfHigh: 85, decoModel: 'Buhlmann ZHL-16C'),
        activityId: 1,
      );

      expect(result.dive.gfLow, 30);
      expect(result.dive.gfHigh, 85);
      expect(result.dive.decoAlgorithm, 'Buhlmann ZHL-16C');
    });

    test('omits an empty deco model rather than storing a blank string', () {
      final result = GarminDiveMapper.map(_dive(decoModel: ''), activityId: 1);
      expect(result.dive.decoAlgorithm, isNull);
    });

    test('maps tanks by order, defaulting a missing o2Percent to air', () {
      final result = GarminDiveMapper.map(
        _dive(
          tanks: const [
            ImportedTank(
              order: 0,
              o2Percent: 32,
              startPressureBar: 200,
              endPressureBar: 50,
              volumeLiters: 12,
            ),
            ImportedTank(order: 1),
          ],
        ),
        activityId: 1,
      );

      expect(result.dive.tanks, hasLength(2));
      expect(result.dive.tanks[0].index, 0);
      expect(result.dive.tanks[0].o2Percent, 32.0);
      expect(result.dive.tanks[0].startPressure, 200.0);
      expect(result.dive.tanks[0].endPressure, 50.0);
      expect(result.dive.tanks[0].volumeLiters, 12.0);
      expect(result.dive.tanks[1].o2Percent, 21.0);
      expect(result.dive.tanks[1].hePercent, 0.0);
    });

    test('maps gas switches, defaulting a missing depth to zero', () {
      final result = GarminDiveMapper.map(
        _dive(
          gasSwitches: const [
            ImportedGasSwitch(timeSeconds: 600, tankIndex: 1, depth: 15.0),
            ImportedGasSwitch(timeSeconds: 1200, tankIndex: 0),
          ],
        ),
        activityId: 1,
      );

      expect(result.dive.gasSwitches, hasLength(2));
      expect(result.dive.gasSwitches[0].timeSeconds, 600);
      expect(result.dive.gasSwitches[0].toTankIndex, 1);
      expect(result.dive.gasSwitches[0].depth, 15.0);
      expect(result.dive.gasSwitches[1].depth, 0.0);
    });

    test('maps a simple single-pressure profile 1:1', () {
      final result = GarminDiveMapper.map(
        _dive(
          profile: const [
            ImportedProfileSample(
              timeSeconds: 0,
              depth: 0.5,
              temperature: 24.0,
              heartRate: 80,
              ndlSeconds: 40 * 60,
              tankPressures: [
                ImportedTankPressureSample(tankIndex: 0, pressureBar: 200),
              ],
            ),
            ImportedProfileSample(
              timeSeconds: 60,
              depth: 12.0,
              ceiling: 3.0,
              ttsSeconds: 5,
            ),
          ],
        ),
        activityId: 1,
      );

      final profile = result.dive.profile;
      expect(profile, hasLength(2));
      expect(profile[0].timeSeconds, 0);
      expect(profile[0].temperature, 24.0);
      expect(profile[0].heartRate, 80);
      expect(profile[0].ndl, 40 * 60);
      expect(profile[0].pressure, 200.0);
      expect(profile[0].tankIndex, 0);
      expect(profile[1].ceiling, 3.0);
      expect(profile[1].tts, 5);
    });

    test('splits multiple simultaneous tank pressures into extra rows at the '
        'same timestamp', () {
      final result = GarminDiveMapper.map(
        _dive(
          profile: const [
            ImportedProfileSample(
              timeSeconds: 300,
              depth: 20.0,
              tankPressures: [
                ImportedTankPressureSample(tankIndex: 0, pressureBar: 180),
                ImportedTankPressureSample(tankIndex: 1, pressureBar: 190),
              ],
            ),
          ],
        ),
        activityId: 1,
      );

      final profile = result.dive.profile;
      expect(profile, hasLength(2));
      expect(profile[0].timeSeconds, 300);
      expect(profile[0].depth, 20.0);
      expect(profile[0].tankIndex, 0);
      expect(profile[0].pressure, 180.0);
      expect(profile[1].timeSeconds, 300);
      expect(profile[1].depth, 20.0);
      expect(profile[1].tankIndex, 1);
      expect(profile[1].pressure, 190.0);
    });
  });
}
