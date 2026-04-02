import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/buddy_extractor.dart';

void main() {
  late BuddyExtractor extractor;

  setUp(() {
    extractor = BuddyExtractor();
  });

  group('BuddyExtractor', () {
    test('extracts single buddy', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': 'Jane Smith'},
      ];

      final buddies = extractor.extractFromRows(rows);

      expect(buddies, hasLength(1));
      expect(buddies[0]['name'], 'Jane Smith');
      expect(buddies[0]['id'], isNotNull);
    });

    test('splits comma-separated buddies', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': 'Jane Smith, John Doe'},
      ];

      final buddies = extractor.extractFromRows(rows);

      expect(buddies, hasLength(2));
      final names = buddies.map((b) => b['name']).toList();
      expect(names, containsAll(['Jane Smith', 'John Doe']));
    });

    test('handles Subsurface leading-comma format', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': ', Kiyan Griffin'},
      ];

      final buddies = extractor.extractFromRows(rows);

      expect(buddies, hasLength(1));
      expect(buddies[0]['name'], 'Kiyan Griffin');
    });

    test('deduplicates across rows', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': 'Jane Smith'},
        {'buddy': 'Jane Smith'},
        {'buddy': 'John Doe'},
      ];

      final buddies = extractor.extractFromRows(rows);

      expect(buddies, hasLength(2));
    });

    test('returns empty for no buddy data', () {
      final rows = <Map<String, dynamic>>[
        {'maxDepth': 25.0},
        {'buddy': null},
        {'buddy': ''},
      ];

      final buddies = extractor.extractFromRows(rows);

      expect(buddies, isEmpty);
    });

    test('buddyIdForName returns consistent ID', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': 'Jane Smith'},
      ];

      extractor.extractFromRows(rows);

      final id1 = extractor.buddyIdForName('Jane Smith');
      final id2 = extractor.buddyIdForName('Jane Smith');
      expect(id1, id2);
      expect(id1, isNotNull);
    });

    test('trims whitespace from buddy names', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': '  Jane Smith  '},
      ];

      final buddies = extractor.extractFromRows(rows);

      expect(buddies, hasLength(1));
      expect(buddies[0]['name'], 'Jane Smith');
    });

    test('filters empty entries after split', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': 'Jane Smith,,John Doe'},
      ];

      final buddies = extractor.extractFromRows(rows);

      expect(buddies, hasLength(2));
    });

    test('buddyIdForName returns null for unseen name', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': 'Jane Smith'},
      ];

      extractor.extractFromRows(rows);

      expect(extractor.buddyIdForName('Unknown Person'), isNull);
    });

    test('each buddy has a uddfId matching its id', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': 'Jane Smith'},
        {'buddy': 'John Doe'},
      ];

      final buddies = extractor.extractFromRows(rows);

      expect(buddies, hasLength(2));
      for (final buddy in buddies) {
        expect(buddy['uddfId'], isNotNull);
        expect(buddy['uddfId'], equals(buddy['id']));
      }
    });

    test('handles Subsurface leading-comma with multiple buddies', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': ', Alice, Bob'},
      ];

      final buddies = extractor.extractFromRows(rows);

      expect(buddies, hasLength(2));
      final names = buddies.map((b) => b['name']).toList();
      expect(names, containsAll(['Alice', 'Bob']));
    });

    test('buddyIdForName returns IDs that match extractFromRows output', () {
      final rows = <Map<String, dynamic>>[
        {'buddy': 'Alice, Bob'},
      ];

      final buddies = extractor.extractFromRows(rows);

      final aliceBuddy = buddies.firstWhere((b) => b['name'] == 'Alice');
      final bobBuddy = buddies.firstWhere((b) => b['name'] == 'Bob');
      expect(extractor.buddyIdForName('Alice'), equals(aliceBuddy['id']));
      expect(extractor.buddyIdForName('Bob'), equals(bobBuddy['id']));
    });
  });
}
