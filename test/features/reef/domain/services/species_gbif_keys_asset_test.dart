import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('species_gbif_keys.json', () {
    late Map<String, dynamic> keys;
    late List<Map<String, dynamic>> catalog;

    setUpAll(() async {
      keys =
          jsonDecode(
                await File('assets/data/species_gbif_keys.json').readAsString(),
              )
              as Map<String, dynamic>;
      final raw =
          jsonDecode(await File('assets/data/species.json').readAsString())
              as Map<String, dynamic>;
      catalog = (raw['species'] as List).cast<Map<String, dynamic>>();
    });

    test('resolves the large majority of the catalog', () {
      final resolved = (keys['speciesKeys'] as Map).length;
      expect(
        resolved,
        greaterThan((catalog.length * 0.75).floor()),
        reason: 'Too few species resolved to GBIF keys; regenerate the asset',
      );
    });

    test('order whitelist is non-empty and plausible', () {
      final orders = (keys['orderKeys'] as List).cast<int>();
      expect(orders, isNotEmpty);
      expect(orders.toSet().length, orders.length, reason: 'no duplicates');
    });

    test('every mapped key points at a real catalog species id', () {
      final ids = catalog.map((s) => s['id'] as String).toSet();
      final mapped = (keys['speciesKeys'] as Map).values.cast<String>();
      for (final id in mapped) {
        expect(ids, contains(id), reason: '$id is not in species.json');
      }
    });

    // The catalog contains four duplicated scientific names whose later copy
    // is miscategorised as generic 'fish'. The generator keeps the first
    // occurrence, which is the correctly categorised one. Last-write-wins
    // would give manta rays and hammerheads a fish icon.
    test('duplicate scientific names resolve to the specific category', () {
      final mapped = (keys['speciesKeys'] as Map).values.cast<String>().toSet();
      final byId = {for (final s in catalog) s['id'] as String: s};

      const expected = {
        'sp_reef_manta_ray': 'ray',
        'sp_giant_oceanic_manta_ray': 'ray',
        'sp_spotted_wobbegong': 'shark',
        'sp_scalloped_hammerhead_shark': 'shark',
      };

      for (final entry in expected.entries) {
        expect(
          mapped,
          contains(entry.key),
          reason: '${entry.key} lost its GBIF key to a duplicate catalog entry',
        );
        expect(byId[entry.key]!['category'], entry.value);
      }
    });

    test('covers every species category including mammals and turtles', () {
      final ids = (keys['speciesKeys'] as Map).values.cast<String>().toSet();
      final coveredCategories = catalog
          .where((s) => ids.contains(s['id']))
          .map((s) => s['category'] as String)
          .toSet();
      expect(coveredCategories, contains('mammal'));
      expect(coveredCategories, contains('turtle'));
      expect(coveredCategories, contains('fish'));
      expect(coveredCategories, contains('coral'));
      expect(coveredCategories, contains('shark'));
    });
  });
}
