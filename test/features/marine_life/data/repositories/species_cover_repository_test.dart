import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/marine_life/data/repositories/species_cover_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species_cover.dart';
import 'package:submersion/features/marine_life/domain/species_revamp_ids.dart';

import '../../../../helpers/test_database.dart';
import 'species_gallery_fixtures.dart';
import 'species_revamp_test_db.dart';

void main() {
  late AppDatabase db;
  late SpeciesCoverRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = SpeciesCoverRepository();
    await insertTestDiver('diver-a');
    await insertTestDiver('diver-b');
    await insertTestSpecies(id: 'grouper', name: 'Grouper');
    await insertTestSpecies(id: 'snapper', name: 'Snapper');
  });
  tearDown(tearDownTestDatabase);

  test('set then read', () async {
    await repository.setCover(
      diverId: 'diver-a',
      speciesId: 'grouper',
      mediaId: 'm1',
      identificationId: 'i1',
    );

    expect(await repository.coversFor('diver-a'), {
      'grouper': const SpeciesCover(
        speciesId: 'grouper',
        mediaId: 'm1',
        identificationId: 'i1',
      ),
    });
    expect(await repository.coversFor('diver-b'), isEmpty);
  });

  test('set again replaces, one row', () async {
    await repository.setCover(
      diverId: 'diver-a',
      speciesId: 'grouper',
      mediaId: 'm1',
      identificationId: 'i1',
    );
    await repository.setCover(
      diverId: 'diver-a',
      speciesId: 'grouper',
      mediaId: 'm2',
    );

    final covers = await repository.coversFor('diver-a');
    expect(covers['grouper']!.mediaId, 'm2');
    expect(covers['grouper']!.identificationId, isNull);
    expect(await db.select(db.speciesCovers).get(), hasLength(1));
  });

  test('clear empties the row instead of deleting it', () async {
    await repository.setCover(
      diverId: 'diver-a',
      speciesId: 'grouper',
      mediaId: 'm1',
    );
    await repository.clearCover(diverId: 'diver-a', speciesId: 'grouper');

    expect(await repository.coversFor('diver-a'), isEmpty);
    final rows = await db.select(db.speciesCovers).get();
    expect(rows.single.mediaId, isNull);
    expect(await deletedRecords(db, 'speciesCovers'), isEmpty);
  });

  test('two devices setting a cover converge on one id', () async {
    expect(
      speciesCoverId('diver-a', 'grouper'),
      speciesCoverId('diver-a', 'grouper'),
    );
    expect(
      speciesCoverId('diver-a', 'grouper'),
      isNot(speciesCoverId('diver-a', 'snapper')),
    );
    expect(
      speciesCoverId('diver-a', 'grouper'),
      isNot(speciesPracticeId('diver-a', 'grouper')),
    );
  });

  test('a write stamps the clock and marks the row pending', () async {
    await repository.setCover(
      diverId: 'diver-a',
      speciesId: 'grouper',
      mediaId: 'm1',
    );

    final row = await db.select(db.speciesCovers).getSingle();
    expect(row.hlc, isNotNull);
    expect(await pendingRecords(db, 'speciesCovers'), [row.id]);
  });
}
