import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/tank_extractor.dart';

void main() {
  late TankExtractor extractor;
  const diveId = 'test-dive-id';

  setUp(() {
    extractor = const TankExtractor();
  });

  group('TankExtractor', () {
    group('numbered tank groups', () {
      test('extracts single tank from row', () {
        final row = <String, dynamic>{
          'tankVolume_1': 12.0,
          'startPressure_1': 200.0,
          'endPressure_1': 50.0,
          'o2Percent_1': 21.0,
          'hePercent_1': 0.0,
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['diveId'], diveId);
        expect(tanks[0]['volume'], 12.0);
        expect(tanks[0]['startPressure'], 200);
        expect(tanks[0]['endPressure'], 50);
        expect(tanks[0]['o2Percent'], 21.0);
        expect(tanks[0]['hePercent'], 0.0);
        expect(tanks[0]['order'], 0);
        expect(tanks[0]['id'], isNotNull);
        expect(tanks[0]['id'], isA<String>());
      });

      test('extracts multiple tanks', () {
        final row = <String, dynamic>{
          'tankVolume_1': 12.0,
          'startPressure_1': 200.0,
          'endPressure_1': 50.0,
          'o2Percent_1': 21.0,
          'hePercent_1': 0.0,
          'tankVolume_2': 7.0,
          'startPressure_2': 180.0,
          'endPressure_2': 30.0,
          'o2Percent_2': 32.0,
          'hePercent_2': 0.0,
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(2));
        expect(tanks[0]['order'], 0);
        expect(tanks[0]['volume'], 12.0);
        expect(tanks[1]['order'], 1);
        expect(tanks[1]['volume'], 7.0);
        expect(tanks[1]['o2Percent'], 32.0);
      });

      test('skips empty tank groups', () {
        final row = <String, dynamic>{
          'tankVolume_1': 12.0,
          'startPressure_1': 200.0,
          'endPressure_1': 50.0,
          'o2Percent_1': 21.0,
          'hePercent_1': 0.0,
          // Group 2 is all null
          'tankVolume_2': null,
          'startPressure_2': null,
          'endPressure_2': null,
          'o2Percent_2': null,
          'hePercent_2': null,
          'tankVolume_3': 10.0,
          'startPressure_3': 150.0,
          'endPressure_3': 20.0,
          'o2Percent_3': 100.0,
          'hePercent_3': 0.0,
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(2));
        expect(tanks[0]['volume'], 12.0);
        expect(tanks[1]['volume'], 10.0);
        expect(tanks[1]['order'], 1);
      });

      test('uses default o2Percent of 21.0 when not provided', () {
        final row = <String, dynamic>{
          'tankVolume_1': 12.0,
          'startPressure_1': 200.0,
          'endPressure_1': 50.0,
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['o2Percent'], 21.0);
        expect(tanks[0]['hePercent'], 0.0);
      });

      test('preserves pressure precision as double', () {
        final row = <String, dynamic>{
          'tankVolume_1': 12.0,
          'startPressure_1': 200.7,
          'endPressure_1': 50.3,
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks[0]['startPressure'], 200.7);
        expect(tanks[0]['endPressure'], 50.3);
      });

      test('skips numbered tanks that have pressure but no volume', () {
        final row = <String, dynamic>{
          // Tank group 1: has volume => should be extracted.
          'tankVolume_1': 12.0,
          'startPressure_1': 200.0,
          'endPressure_1': 50.0,
          'o2Percent_1': 21.0,
          // Tank group 2: pressure only, no volume => should be skipped.
          'startPressure_2': 180.0,
          'endPressure_2': 30.0,
          'o2Percent_2': 32.0,
          // Tank group 3: has volume => should be extracted.
          'tankVolume_3': 7.0,
          'startPressure_3': 150.0,
          'endPressure_3': 20.0,
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(2));
        expect(tanks[0]['volume'], 12.0);
        expect(tanks[1]['volume'], 7.0);
        // Order should be sequential (0, 1), not (0, 2).
        expect(tanks[0]['order'], 0);
        expect(tanks[1]['order'], 1);
      });

      test('skips numbered tank with zero volume parsed from string', () {
        final row = <String, dynamic>{
          'tankVolume_1': '12.0',
          'startPressure_1': '200',
          'tankVolume_2': '',
          'startPressure_2': '180',
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['volume'], 12.0);
      });

      test('converts integer volume to double', () {
        final row = <String, dynamic>{
          'tankVolume_1': 12,
          'startPressure_1': 200,
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['volume'], isA<double>());
        expect(tanks[0]['volume'], 12.0);
      });

      test('parses string values for tank fields', () {
        final row = <String, dynamic>{
          'tankVolume_1': '12.0',
          'startPressure_1': '200',
          'endPressure_1': '50',
          'o2Percent_1': '32.0',
          'hePercent_1': '10.0',
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['volume'], 12.0);
        expect(tanks[0]['startPressure'], 200);
        expect(tanks[0]['endPressure'], 50);
        expect(tanks[0]['o2Percent'], 32.0);
        expect(tanks[0]['hePercent'], 10.0);
      });
    });

    group('flat fallback fields', () {
      test('extracts from legacy flat fields', () {
        final row = <String, dynamic>{
          'startPressure': 200.0,
          'endPressure': 50.0,
          'tankVolume': 12.0,
          'o2Percent': 32.0,
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['diveId'], diveId);
        expect(tanks[0]['volume'], 12.0);
        expect(tanks[0]['startPressure'], 200);
        expect(tanks[0]['endPressure'], 50);
        expect(tanks[0]['o2Percent'], 32.0);
        expect(tanks[0]['hePercent'], 0.0);
        expect(tanks[0]['order'], 0);
      });

      test('returns empty when no tank data', () {
        final row = <String, dynamic>{'diveNumber': 42, 'maxDepth': 25.0};

        final tanks = extractor.extract(row, diveId);

        expect(tanks, isEmpty);
      });

      test('extracts flat fallback with only startPressure', () {
        final row = <String, dynamic>{'startPressure': 200.0};

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['startPressure'], 200);
        expect(tanks[0]['endPressure'], isNull);
        expect(tanks[0]['volume'], isNull);
        expect(tanks[0]['o2Percent'], 21.0);
      });

      test('extracts flat fallback with only endPressure', () {
        final row = <String, dynamic>{'endPressure': 50.0};

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['endPressure'], 50);
        expect(tanks[0]['startPressure'], isNull);
      });

      test('extracts flat fallback with only o2Percent', () {
        final row = <String, dynamic>{'o2Percent': 32.0};

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['o2Percent'], 32.0);
        expect(tanks[0]['volume'], isNull);
      });

      test('extracts flat fallback with only tankVolume', () {
        final row = <String, dynamic>{'tankVolume': 10.0};

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['volume'], 10.0);
        expect(tanks[0]['startPressure'], isNull);
        expect(tanks[0]['endPressure'], isNull);
      });

      test('numbered tanks take priority over flat fallback', () {
        final row = <String, dynamic>{
          // Numbered tank data.
          'tankVolume_1': 12.0,
          'startPressure_1': 200.0,
          // Flat fallback data (should be ignored).
          'startPressure': 150.0,
          'endPressure': 30.0,
          'tankVolume': 8.0,
        };

        final tanks = extractor.extract(row, diveId);

        expect(tanks, hasLength(1));
        expect(tanks[0]['volume'], 12.0);
        expect(tanks[0]['startPressure'], 200);
      });
    });
  });
}
