import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/species_catalogue_restorer.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4578: a UDDF backup's species catalogue was parsed and never
/// restored, so a custom species no dive had sighted was lost on import.
void main() {
  late SpeciesRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SpeciesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('creates each catalogue species the library lacks', () async {
    await restoreSpeciesCatalogue([
      {
        'uddfId': 'species_1',
        'commonName': 'My Own Slug',
        'scientificName': 'Slugus mine',
        'category': SpeciesCategory.invertebrate,
        'taxonomyClass': 'Gastropoda',
        'description': 'Seen once off the pier',
      },
    ], repository);

    final restored = (await repository.findSpeciesByCommonName(
      'My Own Slug',
    )).single;
    expect(restored.scientificName, 'Slugus mine');
    expect(restored.category, SpeciesCategory.invertebrate);
    expect(restored.taxonomyClass, 'Gastropoda');
    expect(restored.description, 'Seen once off the pier');
    expect(restored.isBuiltIn, isFalse);
  });

  test('links to a species already here instead of a twin', () async {
    final existing = await repository.createSpecies(
      commonName: 'Common Octopus',
      scientificName: 'Octopus vulgaris',
      category: SpeciesCategory.invertebrate,
    );
    final before = (await repository.getAllSpecies()).length;

    await restoreSpeciesCatalogue([
      {'commonName': 'Pieuvre commune', 'scientificName': 'Octopus vulgaris'},
      {'commonName': 'Common Octopus', 'scientificName': 'Octopus vulgaris'},
    ], repository);

    expect(await repository.getAllSpecies(), hasLength(before));
    expect(
      (await repository.getSpeciesById(existing.id))?.commonName,
      'Common Octopus',
    );
  });

  test('names a species by its scientific name when it has no common '
      'name, and skips one with neither', () async {
    final before = (await repository.getAllSpecies()).length;

    await restoreSpeciesCatalogue([
      {'scientificName': 'Nameless testus'},
      {'commonName': '  ', 'category': SpeciesCategory.fish},
      {'commonName': 42},
    ], repository);

    final all = await repository.getAllSpecies();
    expect(all, hasLength(before + 1));
    expect(
      (await repository.findSpeciesByCommonName(
        'Nameless testus',
      )).single.scientificName,
      'Nameless testus',
    );
  });
}
