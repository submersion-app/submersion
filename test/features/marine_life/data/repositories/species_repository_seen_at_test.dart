import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #5092: a sighting stores when in the dive it was seen, in seconds
/// from the dive start, or null for no time.
void main() {
  late SpeciesRepository repository;
  late String speciesId;

  Future<void> insertDive(String id) async {
    final db = DatabaseService.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  setUp(() async {
    await setUpTestDatabase();
    repository = SpeciesRepository();
    await insertDive('d1');
    await insertDive('d2');
    speciesId = (await repository.createSpecies(
      commonName: 'Test Jack',
      category: SpeciesCategory.fish,
    )).id;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a sighting added with no time has none', () async {
    final added = await repository.addSighting(
      diveId: 'd1',
      speciesId: speciesId,
    );
    expect(added.seenAtSeconds, isNull);
    expect(
      (await repository.getSightingsForDive('d1')).single.seenAtSeconds,
      isNull,
    );
  });

  test('addSighting stores seenAtSeconds', () async {
    final added = await repository.addSighting(
      diveId: 'd1',
      speciesId: speciesId,
      seenAtSeconds: 720,
    );
    expect(added.seenAtSeconds, 720);
    expect(
      (await repository.getSightingsForDive('d1')).single.seenAtSeconds,
      720,
    );
    expect((await repository.getSightingById(added.id))?.seenAtSeconds, 720);
  });

  test('updateSighting sets and clears a time', () async {
    final added = await repository.addSighting(
      diveId: 'd1',
      speciesId: speciesId,
      seenAtSeconds: 720,
    );
    await repository.updateSighting(added.copyWith(seenAtSeconds: 900));
    expect(
      (await repository.getSightingsForDive('d1')).single.seenAtSeconds,
      900,
    );

    final timed = (await repository.getSightingsForDive('d1')).single;
    await repository.updateSighting(timed.copyWith(clearSeenAt: true));
    expect(
      (await repository.getSightingsForDive('d1')).single.seenAtSeconds,
      isNull,
    );
  });

  test('getSightingsForDives carries seenAtSeconds', () async {
    await repository.addSighting(
      diveId: 'd1',
      speciesId: speciesId,
      seenAtSeconds: 60,
    );
    await repository.addSighting(diveId: 'd2', speciesId: speciesId);
    final byDive = await repository.getSightingsForDives(['d1', 'd2']);
    expect(byDive['d1']!.single.seenAtSeconds, 60);
    expect(byDive['d2']!.single.seenAtSeconds, isNull);
  });

  test('copyWith keeps a time unless told to clear it', () async {
    final added = await repository.addSighting(
      diveId: 'd1',
      speciesId: speciesId,
      seenAtSeconds: 300,
    );
    expect(added.copyWith(notes: 'x').seenAtSeconds, 300);
    expect(added.copyWith(clearSeenAt: true).seenAtSeconds, isNull);
    expect(added.copyWith(notes: 'x'), isNot(added));
    expect(added.copyWith(seenAtSeconds: 301), isNot(added));
  });
}
