import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SpeciesRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SpeciesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('finds a species by scientific name, case-insensitively', () async {
    final created = await repository.createSpecies(
      commonName: 'Whale Shark',
      scientificName: 'Rhincodon typus',
      category: SpeciesCategory.shark,
    );

    final found = await repository.findSpeciesByScientificName(
      'rhincodon TYPUS',
    );

    expect(found?.id, created.id);
  });

  test('returns null for an unknown or empty scientific name', () async {
    expect(await repository.findSpeciesByScientificName('Nomen nudum'), isNull);
    expect(await repository.findSpeciesByScientificName('  '), isNull);
  });
}
