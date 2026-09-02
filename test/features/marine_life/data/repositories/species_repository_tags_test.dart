import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';

void main() {
  late SpeciesRepository species;
  late MediaSpeciesRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    species = SpeciesRepository();
    tags = MediaSpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestMedia(id: 'p1', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a species with a photo tag but no sighting is in use', () async {
    expect(await species.isSpeciesInUse('c1'), isFalse);

    await tags.addTag(mediaId: 'p1', speciesId: 'c1');

    expect(await species.isSpeciesInUse('c1'), isTrue);
  });

  test('deleteSpecies refuses while a tag exists', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');

    expect(() => species.deleteSpecies('c1'), throwsException);
  });

  test('deleteSpecies succeeds once the tag is removed', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');
    await tags.removeTag(mediaId: 'p1', speciesId: 'c1');
    final db = DatabaseService.instance.database;
    expect(await db.select(db.mediaSpecies).get(), isEmpty);

    await species.deleteSpecies('c1');

    expect(await species.getSpeciesById('c1'), isNull);
  });
}
