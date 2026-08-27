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

    test('taxon whitelist is non-empty and plausible', () {
      final taxa = (keys['taxonKeys'] as List).cast<int>();
      expect(taxa, isNotEmpty);
      expect(taxa.toSet().length, taxa.length, reason: 'no duplicates');
    });

    // Issue #1036: a taxon that straddles land and sea drags its terrestrial
    // relatives into the nearby list. Carnivora, admitted because the catalog
    // holds seals and a sea otter, is what put foxes, badgers, martens and
    // polecats in front of a diver at a freshwater quarry.
    test('whitelist excludes taxa that straddle land and sea', () {
      final taxa = (keys['taxonKeys'] as List).cast<int>().toSet();
      const straddlers = {
        732: 'Carnivora, which readmits foxes and cats',
        5307: 'Mustelidae, which readmits badger, marten and polecat',
        9455: 'Elapidae, which readmits cobras, mambas and taipans',
        6935: 'Iguanidae, which readmits tree-dwelling iguanas',
        11418114: 'Testudines as a class, which readmits tortoises',
      };
      for (final entry in straddlers.entries) {
        expect(taxa, isNot(contains(entry.key)), reason: entry.value);
      }
    });

    // Narrowing must stop at the broadest rank that stays aquatic, so seals
    // keep a family and only the sea otter, whose family holds the badger,
    // drops all the way to its genus.
    test('whitelist admits marine mammals at the broadest aquatic rank', () {
      final taxa = (keys['taxonKeys'] as List).cast<int>().toSet();
      expect(taxa, contains(5310), reason: 'Phocidae, all seals');
      expect(taxa, contains(5309), reason: 'Otariidae, all sea lions');
      expect(taxa, contains(2433669), reason: 'Enhydra, the sea otter');
      expect(taxa, contains(733), reason: 'Cetacea, wholly aquatic');
    });

    // GBIF's backbone ranks reptiles as classes, so none of them carries an
    // order key. Collecting order keys alone dropped every marine reptile
    // from the whitelist, which kept green turtles out of the nearby list
    // everywhere on earth.
    test('whitelist admits marine reptiles, which have no GBIF order key', () {
      final taxa = (keys['taxonKeys'] as List).cast<int>().toSet();
      expect(taxa, contains(9413), reason: 'Cheloniidae, hard-shell turtles');
      expect(taxa, contains(5464), reason: 'Dermochelyidae, the leatherback');
      expect(taxa, contains(5685), reason: 'Crocodylidae');
      expect(taxa, contains(2450145), reason: 'Laticauda, the sea kraits');
      expect(taxa, contains(2459538), reason: 'Amblyrhynchus, marine iguana');
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
