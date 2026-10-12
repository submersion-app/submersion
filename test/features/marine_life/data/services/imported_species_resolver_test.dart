import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/imported_species_resolver.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3033: an imported sighting matches on scientific name first, so a
/// species named in another language attaches to the existing row, and a
/// common-name match never crosses a conflicting scientific name.
void main() {
  late SpeciesRepository repository;
  late ImportedSpeciesResolver resolver;

  setUp(() async {
    await setUpTestDatabase();
    repository = SpeciesRepository();
    resolver = ImportedSpeciesResolver(repository);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a scientific name match wins over a different common name', () async {
    final octopus = await repository.createSpecies(
      commonName: 'Common Octopus',
      scientificName: 'Octopus vulgaris',
      category: SpeciesCategory.invertebrate,
    );

    final resolved = await resolver.resolve(
      commonName: 'Pieuvre commune',
      scientificName: 'octopus VULGARIS',
      category: SpeciesCategory.other,
    );

    expect(resolved.id, octopus.id);
    expect(await repository.getAllSpecies(), hasLength(1));
  });

  test('the matched species is left untouched', () async {
    final octopus = await repository.createSpecies(
      commonName: 'Common Octopus',
      scientificName: 'Octopus vulgaris',
      category: SpeciesCategory.invertebrate,
    );

    await resolver.resolve(
      commonName: 'Pieuvre commune',
      scientificName: 'Octopus vulgaris',
      category: SpeciesCategory.fish,
      taxonomyClass: 'Cephalopoda',
      description: 'from the file',
    );

    expect(await repository.getSpeciesById(octopus.id), octopus);
  });

  test('falls back to the common name, ignoring case', () async {
    final wrasse = await repository.createSpecies(
      commonName: 'Cleaner Wrasse',
      category: SpeciesCategory.fish,
    );

    final resolved = await resolver.resolve(
      commonName: 'cleaner wrasse',
      scientificName: 'Labroides dimidiatus',
    );

    expect(resolved.id, wrasse.id);
  });

  test('common names with non-ASCII capitals still match', () async {
    // SQLite's LOWER folds ASCII only, so lowering one side in Dart and the
    // other in SQL never matched "Étoile" against itself.
    final star = await repository.createSpecies(
      commonName: 'Étoile de mer',
      category: SpeciesCategory.invertebrate,
    );

    final resolved = await resolver.resolve(commonName: 'Étoile de mer');

    expect(resolved.id, star.id);
  });

  test('common names differing only in an accented capital match', () async {
    final sponge = await repository.createSpecies(
      commonName: 'ÉPONGE',
      category: SpeciesCategory.invertebrate,
    );

    final resolved = await resolver.resolve(commonName: 'éponge');

    expect(resolved.id, sponge.id);
  });

  test(
    'a scientific name shared by a custom twin resolves to the built-in',
    () async {
      final custom = await repository.createSpecies(
        commonName: 'Pieuvre',
        scientificName: 'Octopus vulgaris',
        category: SpeciesCategory.invertebrate,
      );
      final builtIn = await repository.createSpecies(
        commonName: 'Common Octopus',
        scientificName: 'Octopus vulgaris',
        category: SpeciesCategory.invertebrate,
      );
      await DatabaseService.instance.database.customStatement(
        'UPDATE species SET is_built_in = 1 WHERE id = ?',
        [builtIn.id],
      );

      final resolved = await resolver.resolve(
        commonName: 'Poulpe',
        scientificName: 'Octopus vulgaris',
      );

      expect(resolved.id, builtIn.id);
      expect(resolved.id, isNot(custom.id));
    },
  );

  test('a conflicting scientific name creates a new species', () async {
    final cyanea = await repository.createSpecies(
      commonName: 'Octopus',
      scientificName: 'Octopus cyanea',
      category: SpeciesCategory.invertebrate,
    );

    final resolved = await resolver.resolve(
      commonName: 'Octopus',
      scientificName: 'Octopus vulgaris',
      category: SpeciesCategory.invertebrate,
    );

    expect(resolved.id, isNot(cyanea.id));
    expect(resolved.scientificName, 'Octopus vulgaris');
    expect(await repository.getAllSpecies(), hasLength(2));
  });

  test('a common-name twin with a compatible scientific name is chosen '
      'over one that conflicts', () async {
    await repository.createSpecies(
      commonName: 'Octopus',
      scientificName: 'Octopus cyanea',
      category: SpeciesCategory.invertebrate,
    );
    final plain = await repository.createSpecies(
      commonName: 'Octopus',
      category: SpeciesCategory.invertebrate,
    );

    final resolved = await resolver.resolve(
      commonName: 'Octopus',
      scientificName: 'Octopus vulgaris',
    );

    expect(resolved.id, plain.id);
  });

  test('a new species keeps every field the file gives', () async {
    final resolved = await resolver.resolve(
      commonName: 'Grande crevette rose',
      scientificName: 'Palaemon serratus',
      category: SpeciesCategory.invertebrate,
      taxonomyClass: 'Malacostraca',
      description: 'Rock pools',
    );

    final stored = await repository.getSpeciesById(resolved.id);
    expect(stored?.commonName, 'Grande crevette rose');
    expect(stored?.scientificName, 'Palaemon serratus');
    expect(stored?.category, SpeciesCategory.invertebrate);
    expect(stored?.taxonomyClass, 'Malacostraca');
    expect(stored?.description, 'Rock pools');
    expect(stored?.isBuiltIn, isFalse);
  });

  test('a new species without a category is filed as other', () async {
    final resolved = await resolver.resolve(commonName: 'Mystery Fish');

    expect(resolved.category, SpeciesCategory.other);
  });

  test('blank optional fields are stored as null', () async {
    final resolved = await resolver.resolve(
      commonName: '  Wrasse  ',
      scientificName: '  ',
      taxonomyClass: '',
      description: ' ',
    );

    final stored = await repository.getSpeciesById(resolved.id);
    expect(stored?.commonName, 'Wrasse');
    expect(stored?.scientificName, isNull);
    expect(stored?.taxonomyClass, isNull);
    expect(stored?.description, isNull);
  });
}
