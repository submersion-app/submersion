import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';
import 'species_gallery_fixtures.dart';
import 'species_revamp_test_db.dart';

/// Deleting a custom species tombstones its covers and practice records, so
/// peers drop them with it (#5027).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await insertTestDiver('diver-a');
    await insertTestSpecies(id: 'c1', name: 'My Nudibranch');
    await db
        .into(db.speciesCovers)
        .insert(
          SpeciesCoversCompanion.insert(
            id: 'cover-1',
            diverId: 'diver-a',
            speciesId: 'c1',
            mediaId: const Value('m1'),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.speciesPractice)
        .insert(
          SpeciesPracticeCompanion.insert(
            id: 'practice-1',
            diverId: 'diver-a',
            speciesId: 'c1',
            box: 2,
            dueAt: 1,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  test("tombstones the species' covers and practice rows", () async {
    await SpeciesRepository().deleteSpecies('c1');

    expect(await db.select(db.speciesCovers).get(), isEmpty);
    expect(await db.select(db.speciesPractice).get(), isEmpty);
    expect(await deletedRecords(db, 'speciesCovers'), ['cover-1']);
    expect(await deletedRecords(db, 'speciesPractice'), ['practice-1']);
  });
}
