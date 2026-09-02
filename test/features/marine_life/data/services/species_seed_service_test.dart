import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/services/species_seed_service.dart';

void main() {
  const twoRows = '''
{
  "version": 2,
  "species": [
    {"id": "sp_a", "commonName": "A", "scientificName": "Aus aus",
     "category": "fish", "taxonomyClass": "Actinopterygii", "description": "d"},
    {"id": "sp_b", "commonName": "B", "scientificName": null,
     "category": "nonsense", "taxonomyClass": null, "description": null}
  ]
}
''';

  test('parseCatalog reads the version and every row as built-in', () {
    final catalog = SpeciesSeedService.parseCatalog(twoRows);

    expect(catalog.version, 2);
    expect(catalog.species.map((s) => s.id), ['sp_a', 'sp_b']);
    expect(catalog.species.first.isBuiltIn, isTrue);
    expect(catalog.species.first.category, SpeciesCategory.fish);
    expect(catalog.species.last.category, SpeciesCategory.other);
    expect(catalog.species.last.scientificName, isNull);
  });

  test('a catalog without a version is version 1', () {
    final catalog = SpeciesSeedService.parseCatalog('{"species": []}');

    expect(catalog.version, 1);
    expect(catalog.species, isEmpty);
  });

  test(
    'overrideCatalog feeds loadBundledSpecies until the cache clears',
    () async {
      addTearDown(SpeciesSeedService.clearCache);
      SpeciesSeedService.overrideCatalog(
        SpeciesSeedService.parseCatalog(twoRows),
      );

      final species = await SpeciesSeedService.loadBundledSpecies();
      final catalog = await SpeciesSeedService.loadBundledCatalog();

      expect(species.map((s) => s.id), ['sp_a', 'sp_b']);
      expect(catalog.version, 2);
    },
  );
}
