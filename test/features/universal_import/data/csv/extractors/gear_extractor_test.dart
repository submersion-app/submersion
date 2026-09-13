import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/gear_extractor.dart';

void main() {
  late GearExtractor extractor;

  setUp(() {
    extractor = GearExtractor();
  });

  group('GearExtractor', () {
    test('extracts a wetsuit with its thickness', () {
      final rows = <Map<String, dynamic>>[
        {'suit': '7mm Wetsuit'},
      ];

      final gear = extractor.extractFromRows(rows);

      expect(gear, hasLength(1));
      expect(gear[0]['name'], '7mm Wetsuit');
      expect(gear[0]['type'], 'wetsuit');
      expect(gear[0]['thickness'], '7mm');
      expect(gear[0]['id'], isNotNull);
    });

    test('extracts a drysuit without a thickness', () {
      final gear = extractor.extractFromRows([
        {'suit': '4mm neoprene drysuit'},
      ]);

      expect(gear.single['type'], 'drysuit');
      expect(gear.single.containsKey('thickness'), isFalse);
    });

    test('a wetsuit with no stated thickness carries no thickness key', () {
      final gear = extractor.extractFromRows([
        {'suit': 'Wetsuit'},
      ]);

      expect(gear.single['type'], 'wetsuit');
      expect(gear.single.containsKey('thickness'), isFalse);
    });

    test('an unclear suit creates no gear: it stays in the notes only', () {
      final gear = extractor.extractFromRows([
        {'suit': 'Full suit'},
        {'suit': '7mm Wetsuit'},
      ]);

      expect(gear.map((g) => g['name']), ['7mm Wetsuit']);
      expect(extractor.gearIdForName('Full suit'), isNull);
    });

    group('suit type', () {
      String typeOf(String suit) =>
          extractor.extractFromRows([
                {'suit': suit},
              ]).single['type']
              as String;

      test('types a wetsuit name as wetsuit', () {
        expect(typeOf('7mm Wetsuit'), EquipmentType.wetsuit.name);
      });

      test('types a drysuit name as drysuit', () {
        expect(typeOf('Trilam Drysuit'), EquipmentType.drysuit.name);
      });

      test('keeps a drysuit layer that names itself', () {
        expect(typeOf('Arctic Undersuit'), EquipmentType.undersuit.name);
      });

      test('keeps a base layer that names itself', () {
        expect(typeOf('Fourth Element Thermals'), EquipmentType.baselayer.name);
      });

      test('keeps a rash guard that names itself', () {
        expect(typeOf('Lycra top'), EquipmentType.rashGuard.name);
      });

      test('types a shorty as wetsuit', () {
        expect(typeOf('3mm Shorty'), EquipmentType.wetsuit.name);
      });

      test('reads a thickness as wetsuit where the mapper sees other gear', () {
        // "fin" inside "definition" reads as fins to the free-text mapper,
        // but the suit classifier reads the 6.5mm thickness as a wetsuit.
        expect(typeOf('Scubapro Definition 6.5mm'), EquipmentType.wetsuit.name);
      });

      test('a layer named outright keeps its type even beside "dry"', () {
        expect(typeOf('Dry undersuit'), EquipmentType.undersuit.name);
      });

      test('a name that says neither suit nor layer creates no gear', () {
        // #1885 fell back to wetsuit here; unclear text is not guessed.
        expect(
          extractor.extractFromRows([
            {'suit': 'Full suit'},
          ]),
          isEmpty,
        );
      });
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
      final typesByName = {for (final g in gear) g['name']: g['type']};
      expect(typesByName, {
        '7mm Wetsuit': EquipmentType.wetsuit.name,
        '3mm Shorty': EquipmentType.wetsuit.name,
        'Drysuit': EquipmentType.drysuit.name,
      });
      for (final item in gear) {
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
