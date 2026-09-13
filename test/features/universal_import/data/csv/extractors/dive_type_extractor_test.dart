import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/dive_type_extractor.dart';

void main() {
  const extractor = DiveTypeExtractor();

  group('DiveTypeExtractor', () {
    test('emits each distinct id once, in first-seen order', () {
      final rows = <Map<String, dynamic>>[
        {
          'diveTypeIds': ['night', 'deep_wreck'],
        },
        {
          'diveTypeIds': ['deep_wreck', 'boat'],
        },
      ];

      final types = extractor.extractFromRows(rows);

      expect(types.map((t) => t['id']), ['night', 'deep_wreck', 'boat']);
    });

    test('names a type by the display form of its id', () {
      final types = extractor.extractFromRows([
        {
          'diveTypeIds': ['deep_wreck'],
        },
      ]);

      expect(types.single, {
        'id': 'deep_wreck',
        'uddfId': 'deep_wreck',
        'name': 'Deep wreck',
      });
    });

    test('ignores rows without a type list', () {
      final types = extractor.extractFromRows([
        {'diveType': 'night'},
        {
          'diveTypeIds': ['', 'night'],
        },
      ]);

      expect(types.map((t) => t['id']), ['night']);
    });
  });
}
