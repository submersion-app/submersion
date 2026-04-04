import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/profile_extractor.dart';

void main() {
  late ProfileExtractor extractor;

  setUp(() {
    extractor = const ProfileExtractor();
  });

  group('ProfileExtractor', () {
    test('groups samples by dive key', () {
      final rows = <Map<String, dynamic>>[
        {
          'diveNumber': '1',
          'date': '2023-01-01',
          'time': '09:00',
          'sampleTime': '0:30',
          'sampleDepth': 5.0,
        },
        {
          'diveNumber': '1',
          'date': '2023-01-01',
          'time': '09:00',
          'sampleTime': '1:00',
          'sampleDepth': 10.0,
        },
        {
          'diveNumber': '2',
          'date': '2023-01-01',
          'time': '14:00',
          'sampleTime': '0:30',
          'sampleDepth': 3.0,
        },
      ];

      final grouped = extractor.extractProfiles(rows);

      expect(grouped.keys, hasLength(2));
      expect(grouped['1|2023-01-01|09:00:00'], hasLength(2));
      expect(grouped['2|2023-01-01|14:00:00'], hasLength(1));
    });

    test('extracts depth, temp, pressure, heartrate per sample', () {
      final rows = <Map<String, dynamic>>[
        {
          'diveNumber': '1',
          'date': '2023-01-01',
          'time': '09:00',
          'sampleTime': '1:30',
          'sampleDepth': 15.5,
          'sampleTemperature': 22.0,
          'samplePressure': 180.0,
          'sampleHeartRate': 70,
        },
      ];

      final grouped = extractor.extractProfiles(rows);
      final sample = grouped['1|2023-01-01|09:00:00']!.first;

      expect(sample['depth'], 15.5);
      expect(sample['temperature'], 22.0);
      expect(sample.containsKey('pressure'), isFalse);
      final allTP = sample['allTankPressures'] as List<Map<String, dynamic>>;
      expect(allTP, hasLength(1));
      expect(allTP[0]['pressure'], 180.0);
      expect(allTP[0]['tankIndex'], 0);
      expect(sample['heartRate'], 70);
    });

    test('parses M:SS sample time to seconds', () {
      final rows = <Map<String, dynamic>>[
        {
          'diveNumber': '1',
          'date': '2023-01-01',
          'time': '09:00',
          'sampleTime': '1:30',
          'sampleDepth': 10.0,
        },
      ];

      final grouped = extractor.extractProfiles(rows);
      final sample = grouped['1|2023-01-01|09:00:00']!.first;

      expect(sample['timestamp'], 90);
    });

    test('parses zero seconds: "0:00" -> 0', () {
      final rows = <Map<String, dynamic>>[
        {
          'diveNumber': '1',
          'date': '2023-01-01',
          'time': '09:00',
          'sampleTime': '0:00',
          'sampleDepth': 0.0,
        },
      ];

      final grouped = extractor.extractProfiles(rows);
      final sample = grouped['1|2023-01-01|09:00:00']!.first;

      expect(sample['timestamp'], 0);
    });

    test('parses larger minutes value: "25:45" -> 1545 seconds', () {
      final rows = <Map<String, dynamic>>[
        {
          'diveNumber': '1',
          'date': '2023-01-01',
          'time': '09:00',
          'sampleTime': '25:45',
          'sampleDepth': 5.0,
        },
      ];

      final grouped = extractor.extractProfiles(rows);
      final sample = grouped['1|2023-01-01|09:00:00']!.first;

      expect(sample['timestamp'], 1545);
    });

    test('skips rows without sampleTime', () {
      final rows = <Map<String, dynamic>>[
        {
          'diveNumber': '1',
          'date': '2023-01-01',
          'time': '09:00',
          'maxDepth': 25.0,
          // no sampleTime
        },
      ];

      final grouped = extractor.extractProfiles(rows);

      expect(grouped, isEmpty);
    });

    test('returns empty map for empty input', () {
      final grouped = extractor.extractProfiles([]);

      expect(grouped, isEmpty);
    });
  });
}
