import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/marine_life/data/repositories/species_practice_repository.dart';
import 'package:submersion/features/marine_life/domain/practice/leitner.dart';

import '../../../../helpers/test_database.dart';
import 'species_gallery_fixtures.dart';
import 'species_revamp_test_db.dart';

void main() {
  late AppDatabase db;
  late SpeciesPracticeRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = SpeciesPracticeRepository();
    await insertTestDiver('diver-a');
    await insertTestSpecies(id: 'grouper', name: 'Grouper');
  });
  tearDown(tearDownTestDatabase);

  test('save then read round-trips every field', () async {
    final state = PracticeState(
      speciesId: 'grouper',
      box: 3,
      dueAt: DateTime.utc(2026, 12, 1, 9, 30),
      rightCount: 4,
      wrongCount: 2,
      lastPractisedAt: DateTime.utc(2026, 11, 28, 9, 30),
    );
    await repository.save('diver-a', state);

    expect(await repository.statesFor('diver-a'), {'grouper': state});
  });

  test('saving again updates the one row', () async {
    final now = DateTime.utc(2026, 11, 25);
    await repository.save('diver-a', PracticeState.fresh('grouper', now));
    await repository.save(
      'diver-a',
      applyAnswer(PracticeState.fresh('grouper', now), correct: true, now: now),
    );

    final states = await repository.statesFor('diver-a');
    expect(states['grouper']!.box, 2);
    expect(await db.select(db.speciesPractice).get(), hasLength(1));
  });

  test('save stamps hlc and marks pending', () async {
    await repository.save(
      'diver-a',
      PracticeState.fresh('grouper', DateTime.utc(2026, 11, 25)),
    );

    final row = await db.select(db.speciesPractice).getSingle();
    expect(row.hlc, isNotNull);
    expect(await pendingRecords(db, 'speciesPractice'), [row.id]);
  });
}
