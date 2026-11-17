import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_sitting.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/test_database.dart';

/// A dive's sightings, held in a sitting (issue #4527, plan 6).
void main() {
  late AppDatabase db;
  late SpeciesRepository repo;
  final dive = Dive(id: 'd1', dateTime: DateTime.utc(2026, 3, 9));

  setUp(() async {
    db = await setUpTestDatabase();
    repo = SpeciesRepository();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    for (final (id, name) in [
      ('turtle', 'Green turtle'),
      ('ray', 'Eagle ray'),
      ('manta', 'Manta'),
    ]) {
      await db.customStatement(
        'INSERT INTO species (id, common_name, category) '
        "VALUES ('$id', '$name', 'other')",
      );
    }
    await repo.addSighting(diveId: 'd1', speciesId: 'turtle', count: 2);
    await repo.addSighting(diveId: 'd1', speciesId: 'ray');
  });
  tearDown(tearDownTestDatabase);

  Future<EditSession<Dive>> started() async {
    final session = EditSession<Dive>(dive);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    await diveSightingsList.load(session);
    return session;
  }

  Future<List<Sighting>> stored() => repo.getSightingsForDive('d1');

  test('untouched: nothing written', () async {
    final session = await started();
    expect(diveSightingsList.current(session), hasLength(2));
    expect(session.isDirty, isFalse);
    await session.runHeldWrites();
    expect(await stored(), hasLength(2));
  });

  test(
    'a sighting added, one changed and one removed: each written once',
    () async {
      final session = await started();
      final turtle = diveSightingsList
          .current(session)!
          .firstWhere((s) => s.speciesId == 'turtle');
      diveSightingsList.set(session, [
        turtle.copyWith(notes: 'Resting'),
        const Sighting(
          id: 'fresh',
          diveId: 'd1',
          speciesId: 'manta',
          speciesName: 'Manta',
          speciesCategory: SpeciesCategory.ray,
        ),
      ]);
      expect(session.changedCardIds, {'sightings'});

      await session.runHeldWrites();
      final after = await stored();
      expect({for (final s in after) s.speciesId}, {'turtle', 'manta'});
      expect(after.firstWhere((s) => s.speciesId == 'turtle').notes, 'Resting');
      // The added sighting is written under an id of the database's own.
      expect(
        after.firstWhere((s) => s.speciesId == 'manta').id,
        isNot('fresh'),
      );
    },
  );

  test('a sighting added on another device during the sitting survives a Save '
      'that removed another', () async {
    final session = await started();
    await repo.addSighting(diveId: 'd1', speciesId: 'manta');
    final turtle = diveSightingsList
        .current(session)!
        .firstWhere((s) => s.speciesId == 'turtle');
    diveSightingsList.set(session, [turtle]);

    await session.runHeldWrites();
    expect({for (final s in await stored()) s.speciesId}, {'turtle', 'manta'});
  });

  test('the same sightings in another order are no change', () async {
    final session = await started();
    diveSightingsList.set(
      session,
      diveSightingsList.current(session)!.reversed.toList(),
    );
    expect(session.isDirty, isFalse);
  });

  // Code review (#4527): a sighting sync moved to another dive while the
  // sitting was open is that dive's now, whatever the sitting did to it.
  group('a sighting sync moved to another dive before Save', () {
    Future<(EditSession<Dive>, Sighting)> movedAway() async {
      await db.customStatement(
        'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
        "VALUES ('d2', 0, 0, 0)",
      );
      final session = await started();
      final turtle = diveSightingsList
          .current(session)!
          .firstWhere((s) => s.speciesId == 'turtle');
      return (session, turtle);
    }

    Future<void> moveToD2(String id) => db.customStatement(
      "UPDATE sightings SET dive_id = 'd2' WHERE id = ?",
      [id],
    );

    test('is not deleted by a Save that removed it', () async {
      final (session, turtle) = await movedAway();
      diveSightingsList.set(session, [
        for (final s in diveSightingsList.current(session)!)
          if (s.id != turtle.id) s,
      ]);
      await moveToD2(turtle.id);

      await session.runHeldWrites();
      expect((await repo.getSightingsForDive('d2')).map((s) => s.id), [
        turtle.id,
      ]);
    });

    test('is not overwritten by a Save that changed it', () async {
      final (session, turtle) = await movedAway();
      diveSightingsList.set(session, [
        for (final s in diveSightingsList.current(session)!)
          s.id == turtle.id ? s.copyWith(notes: 'Resting') : s,
      ]);
      await moveToD2(turtle.id);

      await session.runHeldWrites();
      final moved = (await repo.getSightingsForDive('d2')).single;
      expect(moved.notes, isNot('Resting'));
    });
  });
}
