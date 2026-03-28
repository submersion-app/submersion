import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_dive_mapper.dart';

void main() {
  group('ShearwaterDiveMapper', () {
    group('mapDive', () {
      test('falls back to metadata when no decompressed data', () async {
        const rawDive = ShearwaterRawDive(
          diveId: 'ffi-test',
          diveDate: '2025-06-15 10:30:00',
          depth: 20.0,
          diveLengthTime: 3000,
        );

        final warnings = <ImportWarning>[];
        final result = await ShearwaterDiveMapper.mapDive(
          rawDive,
          warnings: warnings,
        );

        expect(result['importSource'], 'shearwater_cloud');
        expect(result['importId'], 'ffi-test');
        expect(result['maxDepth'], 20.0);
        // No warning expected because there was no decompressed data to parse
        expect(warnings, isEmpty);
      });

      test('rethrows platform exception from FFI', () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        // Provide decompressed data so it attempts FFI parsing.
        // In the test environment, the Pigeon channel throws a
        // PlatformException (channel-error). Platform-level errors are
        // rethrown so the parser can detect FFI is unavailable.
        final rawDive = ShearwaterRawDive(
          diveId: 'ffi-test',
          diveDate: '2025-06-15 10:30:00',
          depth: 20.0,
          diveLengthTime: 3000,
          fileName: 'Teric[AABB1234]#10 2025-06-15 10-30-00.swlogzp',
          decompressedLogData: Uint8List.fromList(List.filled(100, 0)),
        );

        expect(
          () => ShearwaterDiveMapper.mapDive(rawDive),
          throwsA(isA<PlatformException>()),
        );
      });

      test('returns metadata only when model is unknown', () async {
        final rawDive = ShearwaterRawDive(
          diveId: 'test-unknown',
          fileName: 'UnknownModel[ABCD]#1 2025-1-1 0-0-0.swlogzp',
          decompressedLogData: Uint8List.fromList([1, 2, 3]),
        );
        final warnings = <ImportWarning>[];
        final result = await ShearwaterDiveMapper.mapDive(
          rawDive,
          warnings: warnings,
        );
        expect(result['profile'], isEmpty);
        expect(warnings, isNotEmpty);
        expect(warnings.first.message, contains('Could not determine'));
        expect(warnings.first.severity, ImportWarningSeverity.warning);
        expect(warnings.first.entityType, ImportEntityType.dives);
      });
    });

    group('mergeWithParsedDive', () {
      test('overrides depth/duration from parsed data', () {
        final baseMap = <String, dynamic>{
          'maxDepth': 10.0,
          'avgDepth': 5.0,
          'runtime': const Duration(seconds: 100),
          'profile': <Map<String, dynamic>>[],
        };
        final parsed = pigeon.ParsedDive(
          fingerprint: 'abc',
          dateTimeYear: 2025,
          dateTimeMonth: 12,
          dateTimeDay: 27,
          dateTimeHour: 14,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 26.8,
          avgDepthMeters: 19.4,
          durationSeconds: 1764,
          samples: [],
          tanks: [],
          gasMixes: [],
          events: [],
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        expect(result['maxDepth'], 26.8);
        expect(result['avgDepth'], 19.4);
        expect((result['runtime'] as Duration).inSeconds, 1764);
      });

      test('adds deco algorithm and GF from parsed data', () {
        final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
        final parsed = pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 2025,
          dateTimeMonth: 1,
          dateTimeDay: 1,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 0,
          avgDepthMeters: 0,
          durationSeconds: 0,
          samples: [],
          tanks: [],
          gasMixes: [],
          events: [],
          decoAlgorithm: 'buhlmann',
          gfLow: 30,
          gfHigh: 70,
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        expect(result['decoAlgorithm'], 'buhlmann');
        expect(result['gradientFactorLow'], 30);
        expect(result['gradientFactorHigh'], 70);
      });

      test('does not add deco fields when absent in parsed data', () {
        final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
        final parsed = pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 2025,
          dateTimeMonth: 1,
          dateTimeDay: 1,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 0,
          avgDepthMeters: 0,
          durationSeconds: 0,
          samples: [],
          tanks: [],
          gasMixes: [],
          events: [],
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        expect(result.containsKey('decoAlgorithm'), isFalse);
        expect(result.containsKey('gradientFactorLow'), isFalse);
        expect(result.containsKey('gradientFactorHigh'), isFalse);
      });

      test('maps dive mode from parsed data', () {
        final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
        final parsed = pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 2025,
          dateTimeMonth: 1,
          dateTimeDay: 1,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 0,
          avgDepthMeters: 0,
          durationSeconds: 0,
          samples: [],
          tanks: [],
          gasMixes: [],
          events: [],
          diveMode: 'ccr',
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        expect(result['diveMode'], DiveMode.ccr);
      });

      test('maps scr dive mode from parsed data', () {
        final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
        final parsed = pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 2025,
          dateTimeMonth: 1,
          dateTimeDay: 1,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 0,
          avgDepthMeters: 0,
          durationSeconds: 0,
          samples: [],
          tanks: [],
          gasMixes: [],
          events: [],
          diveMode: 'scr',
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        expect(result['diveMode'], DiveMode.scr);
      });

      test('maps unknown dive mode to oc', () {
        final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
        final parsed = pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 2025,
          dateTimeMonth: 1,
          dateTimeDay: 1,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 0,
          avgDepthMeters: 0,
          durationSeconds: 0,
          samples: [],
          tanks: [],
          gasMixes: [],
          events: [],
          diveMode: 'gauge',
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        expect(result['diveMode'], DiveMode.oc);
      });

      test('builds profile samples with all sensor data', () {
        final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
        final parsed = pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 2025,
          dateTimeMonth: 1,
          dateTimeDay: 1,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 20,
          avgDepthMeters: 10,
          durationSeconds: 600,
          samples: [
            pigeon.ProfileSample(
              timeSeconds: 10,
              depthMeters: 5.0,
              temperatureCelsius: 22.0,
              pressureBar: 200.0,
              setpoint: 1.3,
              ppo2: 1.1,
              heartRate: 80,
              cns: 5.0,
              rbt: 60,
              tts: 120,
              decoType: 0,
              decoTime: 99,
              decoDepth: 3.0,
            ),
            pigeon.ProfileSample(timeSeconds: 20, depthMeters: 10.0),
          ],
          tanks: [],
          gasMixes: [],
          events: [],
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        final profile = result['profile'] as List;
        expect(profile, hasLength(2));

        final s1 = profile[0] as Map<String, dynamic>;
        expect(s1['timestamp'], 10);
        expect(s1['depth'], 5.0);
        expect(s1['temperature'], 22.0);
        expect(s1['pressure'], 200.0);
        expect(s1['setpoint'], 1.3);
        expect(s1['ppO2'], 1.1);
        expect(s1['heartRate'], 80);
        expect(s1['cns'], 5.0);
        expect(s1['rbt'], 60);
        expect(s1['tts'], 120);
        expect(s1['decoType'], 0);
        expect(s1.containsKey('ceiling'), isFalse);
        expect(s1['ndl'], 99);

        // Second sample has only depth -- no optional fields
        final s2 = profile[1] as Map<String, dynamic>;
        expect(s2['timestamp'], 20);
        expect(s2['depth'], 10.0);
        expect(s2.containsKey('temperature'), isFalse);
        expect(s2.containsKey('pressure'), isFalse);
        expect(s2.containsKey('setpoint'), isFalse);
        expect(s2.containsKey('ppO2'), isFalse);
        expect(s2.containsKey('heartRate'), isFalse);
        expect(s2.containsKey('cns'), isFalse);
        expect(s2.containsKey('rbt'), isFalse);
        expect(s2.containsKey('tts'), isFalse);
        expect(s2.containsKey('decoType'), isFalse);
        expect(s2.containsKey('ceiling'), isFalse);
        expect(s2.containsKey('ndl'), isFalse);
      });

      test('maps deco stop samples with ceiling and no ndl', () {
        final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
        final parsed = pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 2025,
          dateTimeMonth: 1,
          dateTimeDay: 1,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 30,
          avgDepthMeters: 20,
          durationSeconds: 1800,
          samples: [
            pigeon.ProfileSample(
              timeSeconds: 10,
              depthMeters: 25.0,
              decoType: 2,
              decoTime: 180,
              decoDepth: 6.0,
            ),
          ],
          tanks: [],
          gasMixes: [],
          events: [],
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        final profile = result['profile'] as List;
        final s1 = profile[0] as Map<String, dynamic>;
        expect(s1['decoType'], 2);
        expect(s1['ceiling'], 6.0);
        expect(s1.containsKey('ndl'), isFalse);
      });

      test('extracts water temp from samples when not in metadata', () {
        final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
        final parsed = pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 2025,
          dateTimeMonth: 1,
          dateTimeDay: 1,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 10,
          avgDepthMeters: 5,
          durationSeconds: 300,
          samples: [
            pigeon.ProfileSample(
              timeSeconds: 10,
              depthMeters: 5.0,
              temperatureCelsius: 22.0,
            ),
            pigeon.ProfileSample(
              timeSeconds: 20,
              depthMeters: 8.0,
              temperatureCelsius: 20.0,
            ),
          ],
          tanks: [],
          gasMixes: [],
          events: [],
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        expect(result['waterTemp'], 20.0); // min temperature
      });

      test('does not override existing waterTemp', () {
        final baseMap = <String, dynamic>{
          'waterTemp': 25.0,
          'profile': <Map<String, dynamic>>[],
        };
        final parsed = pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 2025,
          dateTimeMonth: 1,
          dateTimeDay: 1,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 10,
          avgDepthMeters: 5,
          durationSeconds: 300,
          samples: [
            pigeon.ProfileSample(
              timeSeconds: 10,
              depthMeters: 5.0,
              temperatureCelsius: 20.0,
            ),
          ],
          tanks: [],
          gasMixes: [],
          events: [],
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        expect(result['waterTemp'], 25.0); // unchanged
      });

      test('does not set waterTemp when no temperature samples exist', () {
        final baseMap = <String, dynamic>{'profile': <Map<String, dynamic>>[]};
        final parsed = pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 2025,
          dateTimeMonth: 1,
          dateTimeDay: 1,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 10,
          avgDepthMeters: 5,
          durationSeconds: 300,
          samples: [pigeon.ProfileSample(timeSeconds: 10, depthMeters: 5.0)],
          tanks: [],
          gasMixes: [],
          events: [],
        );
        final result = ShearwaterDiveMapper.mergeWithParsedDive(
          baseMap,
          parsed,
        );
        expect(result['waterTemp'], isNull);
      });
    });
  });
}
