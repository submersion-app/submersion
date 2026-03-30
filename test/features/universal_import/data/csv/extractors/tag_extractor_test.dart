import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/tag_extractor.dart';

void main() {
  late TagExtractor extractor;

  setUp(() {
    extractor = TagExtractor();
  });

  group('TagExtractor', () {
    test('extracts single tag', () {
      final rows = <Map<String, dynamic>>[
        {'tags': 'reef'},
      ];

      final tags = extractor.extractFromRows(rows);

      expect(tags, hasLength(1));
      expect(tags[0]['name'], 'reef');
      expect(tags[0]['id'], isNotNull);
    });

    test('splits comma-separated tags', () {
      final rows = <Map<String, dynamic>>[
        {'tags': 'reef, turtle, shark'},
      ];

      final tags = extractor.extractFromRows(rows);

      expect(tags, hasLength(3));
      final names = tags.map((t) => t['name']).toList();
      expect(names, containsAll(['reef', 'turtle', 'shark']));
    });

    test('deduplicates across rows', () {
      final rows = <Map<String, dynamic>>[
        {'tags': 'reef'},
        {'tags': 'reef'},
        {'tags': 'wreck'},
      ];

      final tags = extractor.extractFromRows(rows);

      expect(tags, hasLength(2));
    });

    test('trims whitespace from tag names', () {
      final rows = <Map<String, dynamic>>[
        {'tags': '  reef  ,  wreck  '},
      ];

      final tags = extractor.extractFromRows(rows);

      expect(tags, hasLength(2));
      final names = tags.map((t) => t['name']).toList();
      expect(names, containsAll(['reef', 'wreck']));
    });

    test('returns empty for no tag data', () {
      final rows = <Map<String, dynamic>>[
        {'maxDepth': 25.0},
        {'tags': null},
        {'tags': ''},
      ];

      final tags = extractor.extractFromRows(rows);

      expect(tags, isEmpty);
    });

    test('tagIdForName returns consistent ID', () {
      final rows = <Map<String, dynamic>>[
        {'tags': 'reef'},
      ];

      extractor.extractFromRows(rows);

      final id1 = extractor.tagIdForName('reef');
      final id2 = extractor.tagIdForName('reef');
      expect(id1, id2);
      expect(id1, isNotNull);
    });

    test('filters empty entries after split', () {
      final rows = <Map<String, dynamic>>[
        {'tags': 'reef,,wreck'},
      ];

      final tags = extractor.extractFromRows(rows);

      expect(tags, hasLength(2));
    });
  });
}
