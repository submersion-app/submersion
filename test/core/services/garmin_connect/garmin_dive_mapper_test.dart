import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/garmin_connect/garmin_connect_client.dart';
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
  int? bottomTimeSeconds,
  int? surfaceIntervalSeconds,
  String? waterType,
  double? cnsEnd,
  double? otu,
  double? exitLatitude = 10.1,
  double? exitLongitude = 20.1,
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
    exitLatitude: exitLatitude,
    exitLongitude: exitLongitude,
    computerModel: 'Descent Mk2',
    computerSerial: 'SN-42',
    computerFirmware: '5.10',
    gfLow: gfLow,
    gfHigh: gfHigh,
    decoModel: decoModel,
    bottomTimeSeconds: bottomTimeSeconds,
    surfaceIntervalSeconds: surfaceIntervalSeconds,
    waterType: waterType,
    cnsEnd: cnsEnd,
    otu: otu,
    tanks: tanks,
    gasSwitches: gasSwitches,
    profile: profile,
  );
}

GarminActivitySummary _summary({
  int activityId = 77,
  DateTime? localStartTime,
  double? maxDepth = 12.4,
  int? durationSeconds = 2400,
  double? latitude = 25.1,
  double? longitude = -80.3,
  double? exitLatitude = 25.2,
  double? exitLongitude = -80.4,
  String? notes,
}) => GarminActivitySummary(
  activityId: activityId,
  startTime: DateTime.utc(2026, 3, 15, 14, 5),
  localStartTime: localStartTime,
  activityType: 'single_gas_diving',
  maxDepth: maxDepth,
  durationSeconds: durationSeconds,
  latitude: latitude,
  longitude: longitude,
  exitLatitude: exitLatitude,
  exitLongitude: exitLongitude,
  notes: notes,
);

void main() {
  // Issue #2410: a dive Connect cannot export as FIT, such as one entered by
  // hand, is imported from what the activity summary already carries.
  group('GarminDiveMapper.fromSummary', () {
    test('maps the summary header onto a dive with no profile', () {
      final result = GarminDiveMapper.fromSummary(
        _summary(localStartTime: DateTime.utc(2026, 3, 15, 9, 5)),
      );

      expect(result.dive.durationSeconds, 2400);
      expect(result.dive.maxDepth, 12.4);
      expect(result.dive.profile, isEmpty);
      expect(result.dive.tanks, isEmpty);
      expect(result.dive.entryLatitude, 25.1);
      expect(result.dive.entryLongitude, -80.3);
      expect(result.dive.exitLatitude, 25.2);
      expect(result.dive.exitLongitude, -80.4);
      expect(result.profileMissing, isTrue);
    });

    test('keeps the local wall-clock start, like a FIT import does', () {
      // Dive times are stored as wall-clock-as-UTC. startTimeGMT is a real
      // instant, so using it would shift the dive by the diver's UTC offset.
      final result = GarminDiveMapper.fromSummary(
        _summary(localStartTime: DateTime.utc(2026, 3, 15, 9, 5)),
      );

      expect(result.dive.startTime, DateTime.utc(2026, 3, 15, 9, 5));
    });

    test('falls back to the UTC start when Connect gave no local one', () {
      final result = GarminDiveMapper.fromSummary(_summary());

      expect(result.dive.startTime, DateTime.utc(2026, 3, 15, 14, 5));
    });

    test('shares the FIT route fingerprint so a re-import dedupes', () {
      final fromSummary = GarminDiveMapper.fromSummary(
        _summary(activityId: 123),
      );
      final fromFit = GarminDiveMapper.map(_dive(), activityId: 123);

      expect(fromSummary.dive.rawFingerprint, fromFit.dive.rawFingerprint);
    });

    test('uses zero for a depth or duration the summary lacks', () {
      final result = GarminDiveMapper.fromSummary(
        _summary(maxDepth: null, durationSeconds: null),
      );

      expect(result.dive.maxDepth, 0);
      expect(result.dive.durationSeconds, 0);
    });

    test('never pairs a latitude with a missing longitude', () {
      final result = GarminDiveMapper.fromSummary(
        _summary(longitude: null, exitLatitude: null),
      );

      expect(result.dive.entryLatitude, isNull);
      expect(result.dive.entryLongitude, isNull);
      expect(result.dive.exitLatitude, isNull);
      expect(result.dive.exitLongitude, isNull);
    });

    test('carries the Connect notes and names the device plain Garmin', () {
      final result = GarminDiveMapper.fromSummary(
        _summary(notes: 'Drift along the wall'),
      );

      expect(result.notes, 'Drift along the wall');
      expect(result.deviceModel, 'Garmin');
      expect(result.serialNumber, isNull);
    });
  });

  group('GarminDiveMapper.map notes', () {
    test('carries the Connect notes alongside the FIT dive', () {
      final result = GarminDiveMapper.map(
        _dive(),
        activityId: 1,
        notes: 'Drift along the wall',
      );

      expect(result.notes, 'Drift along the wall');
      expect(result.profileMissing, isFalse);
    });
  });

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

    // Issue #1798: the FIT file import kept these dive_summary and
    // dive_settings values while the Cloud import of the same dive lost them.
    test('carries the FIT summary bottom time, surface interval, water type, '
        'CNS and OTU', () {
      final result = GarminDiveMapper.map(
        _dive(
          bottomTimeSeconds: 3600,
          surfaceIntervalSeconds: 5400,
          waterType: 'salt',
          cnsEnd: 14.0,
          otu: 38.0,
        ),
        activityId: 1,
      );

      expect(result.dive.bottomTimeSeconds, 3600);
      expect(result.dive.surfaceIntervalSeconds, 5400);
      expect(result.dive.waterType, WaterType.salt);
      expect(result.dive.cnsEnd, 14.0);
      expect(result.dive.otu, 38.0);
    });

    test('maps fresh water, and leaves a FIT water type with no log '
        'equivalent unset', () {
      final fresh = GarminDiveMapper.map(
        _dive(waterType: 'fresh'),
        activityId: 1,
      );
      final en13319 = GarminDiveMapper.map(
        _dive(waterType: 'en13319'),
        activityId: 1,
      );

      expect(fresh.dive.waterType, WaterType.fresh);
      expect(en13319.dive.waterType, isNull);
    });

    test('leaves the summary fields unset when the FIT file has none', () {
      final result = GarminDiveMapper.map(_dive(), activityId: 1);

      expect(result.dive.bottomTimeSeconds, isNull);
      expect(result.dive.surfaceIntervalSeconds, isNull);
      expect(result.dive.waterType, isNull);
      expect(result.dive.cnsEnd, isNull);
      expect(result.dive.otu, isNull);
    });

    test('falls back to Connect\'s activity-list end position for the exit '
        'when the FIT file has none (issue #1797)', () {
      final result = GarminDiveMapper.map(
        _dive(exitLatitude: null, exitLongitude: null),
        activityId: 1,
        fallbackExitLatitude: 28.4612,
        fallbackExitLongitude: -16.3251,
      );

      expect(result.dive.exitLatitude, 28.4612);
      expect(result.dive.exitLongitude, -16.3251);
      expect(result.dive.entryLatitude, 10.0);
      expect(result.dive.entryLongitude, 20.0);
    });

    test('prefers the FIT file\'s own exit position over the fallback', () {
      final result = GarminDiveMapper.map(
        _dive(),
        activityId: 1,
        fallbackExitLatitude: 99.0,
        fallbackExitLongitude: 99.0,
      );

      expect(result.dive.exitLatitude, 10.1);
      expect(result.dive.exitLongitude, 20.1);
    });

    test(
      'ignores a lone fallback exit latitude with no matching longitude',
      () {
        final result = GarminDiveMapper.map(
          _dive(exitLatitude: null, exitLongitude: null),
          activityId: 1,
          fallbackExitLatitude: 28.4612,
        );

        expect(result.dive.exitLatitude, isNull);
        expect(result.dive.exitLongitude, isNull);
      },
    );

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

    test('keeps simultaneous tank pressures on one row', () {
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
      expect(profile, hasLength(1));
      expect(profile.single.timeSeconds, 300);
      expect(profile.single.depth, 20.0);
      expect(profile.single.tankPressures, [180.0, 190.0]);
      // The single pair holds the last reading, as ProfileSample documents.
      expect(profile.single.tankIndex, 1);
      expect(profile.single.pressure, 190.0);
    });

    test('leaves a gap for a tank that reported nothing', () {
      final result = GarminDiveMapper.map(
        _dive(
          profile: const [
            ImportedProfileSample(
              timeSeconds: 300,
              depth: 20.0,
              tankPressures: [
                ImportedTankPressureSample(tankIndex: 2, pressureBar: 150),
                ImportedTankPressureSample(tankIndex: 0, pressureBar: 180),
              ],
            ),
          ],
        ),
        activityId: 1,
      );

      expect(result.dive.profile.single.tankPressures, [180.0, null, 150.0]);
    });
  });
}
