import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/gear_extractor.dart';

void main() {
  late GearExtractor extractor;

  setUp(() {
    extractor = GearExtractor();
  });

  group('GearExtractor', () {
    test('extracts suit as gear with type exposure_suit', () {
      final rows = <Map<String, dynamic>>[
        {'suit': '7mm Wetsuit'},
      ];

      final gear = extractor.extractFromRows(rows);

      expect(gear, hasLength(1));
      expect(gear[0]['name'], '7mm Wetsuit');
      expect(gear[0]['type'], 'exposure_suit');
      expect(gear[0]['id'], isNotNull);
    });

    test('deduplicates by name across rows', () {
      final rows = <Map<String, dynamic>>[
        {'suit': '7mm Wetsuit'},
        {'suit': '7mm Wetsuit'},
        {'suit': '7mm Wetsuit'},
      ];

      final gear = extractor.extractFromRows(rows);

      expect(gear, hasLength(1));
      expect(gear[0]['name'], '7mm Wetsuit');
    });

    test('skips rows without suit field', () {
      final rows = <Map<String, dynamic>>[
        {'maxDepth': 25.0},
        {'buddy': 'Jane Smith'},
      ];

      final gear = extractor.extractFromRows(rows);

      expect(gear, isEmpty);
    });

    test('skips empty suit values', () {
      final rows = <Map<String, dynamic>>[
        {'suit': ''},
        {'suit': '   '},
        {'suit': null},
      ];

      final gear = extractor.extractFromRows(rows);

      expect(gear, isEmpty);
    });

    test('gearIdForName returns correct ID after extraction', () {
      final rows = <Map<String, dynamic>>[
        {'suit': '7mm Wetsuit'},
      ];

      final gear = extractor.extractFromRows(rows);
      final id = extractor.gearIdForName('7mm Wetsuit');

      expect(id, isNotNull);
      expect(id, gear[0]['id']);
    });

    test('gearIdForName returns null for unseen names', () {
      final rows = <Map<String, dynamic>>[
        {'suit': '7mm Wetsuit'},
      ];

      extractor.extractFromRows(rows);

      expect(extractor.gearIdForName('Drysuit'), isNull);
    });

    test('multiple different suits produce multiple entries', () {
      final rows = <Map<String, dynamic>>[
        {'suit': '7mm Wetsuit'},
        {'suit': '3mm Shorty'},
        {'suit': 'Drysuit'},
      ];

      final gear = extractor.extractFromRows(rows);

      expect(gear, hasLength(3));
      final names = gear.map((g) => g['name']).toList();
      expect(names, containsAll(['7mm Wetsuit', '3mm Shorty', 'Drysuit']));
      for (final item in gear) {
        expect(item['type'], 'exposure_suit');
        expect(item['id'], isNotNull);
      }
    });

    test('gearIdForName returns consistent ID across calls', () {
      final rows = <Map<String, dynamic>>[
        {'suit': '7mm Wetsuit'},
      ];

      extractor.extractFromRows(rows);

      final id1 = extractor.gearIdForName('7mm Wetsuit');
      final id2 = extractor.gearIdForName('7mm Wetsuit');
      expect(id1, id2);
      expect(id1, isNotNull);
    });

    test('trims whitespace from suit names', () {
      final rows = <Map<String, dynamic>>[
        {'suit': '  7mm Wetsuit  '},
      ];

      final gear = extractor.extractFromRows(rows);

      expect(gear, hasLength(1));
      expect(gear[0]['name'], '7mm Wetsuit');
    });

    test('each gear item has a uddfId matching its id', () {
      final rows = <Map<String, dynamic>>[
        {'suit': '7mm Wetsuit'},
        {'suit': '3mm Shorty'},
      ];

      final gear = extractor.extractFromRows(rows);

      expect(gear, hasLength(2));
      for (final item in gear) {
        expect(item['uddfId'], isNotNull);
        expect(item['uddfId'], equals(item['id']));
      }
    });

    test('gearIdForName returns ID that matches extractFromRows output', () {
      final rows = <Map<String, dynamic>>[
        {'suit': '7mm Wetsuit'},
        {'suit': '3mm Shorty'},
      ];

      final gear = extractor.extractFromRows(rows);

      final wetsuit = gear.firstWhere((g) => g['name'] == '7mm Wetsuit');
      final shorty = gear.firstWhere((g) => g['name'] == '3mm Shorty');
      expect(extractor.gearIdForName('7mm Wetsuit'), equals(wetsuit['id']));
      expect(extractor.gearIdForName('3mm Shorty'), equals(shorty['id']));
    });
  });
}
