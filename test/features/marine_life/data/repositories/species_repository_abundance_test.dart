import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #4337: a sighting stores Seen, a REEF group or an exact count.
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

  Future<domain.Sighting> readBack(String diveId) async =>
      (await repository.getSightingsForDive(diveId)).single;

  test('a sighting added with no amount is Seen', () async {
    final added = await repository.addSighting(
      diveId: 'd1',
      speciesId: speciesId,
    );
    expect(added.abundance, SightingAbundance.seen);
    final stored = await readBack('d1');
    expect(stored.abundance, SightingAbundance.seen);
    expect(stored.count, 1);
  });

  test('an exact count reads back exact', () async {
    await repository.addSighting(
      diveId: 'd1',
      speciesId: speciesId,
      abundance: SightingAbundance.exact,
      count: 3,
    );
    final stored = await readBack('d1');
    expect(stored.amount, (abundance: SightingAbundance.exact, count: 3));
  });

  test('a REEF group stores count 1 whatever it was given', () async {
    await repository.addSighting(
      diveId: 'd1',
      speciesId: speciesId,
      abundance: SightingAbundance.few,
      count: 9,
    );
    final stored = await readBack('d1');
    expect(stored.amount, (abundance: SightingAbundance.few, count: 1));
  });

  test('updateSighting moves a Seen sighting to an exact count', () async {
    final added = await repository.addSighting(
      diveId: 'd1',
      speciesId: speciesId,
    );
    await repository.updateSighting(
      added.copyWith(abundance: SightingAbundance.exact, count: 5),
    );
    final stored = await readBack('d1');
    expect(stored.amount, (abundance: SightingAbundance.exact, count: 5));
  });

  test('a row from before v350 (null abundance) reads as exact', () async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO sightings (id, dive_id, species_id, count) "
      "VALUES ('old', 'd1', '$speciesId', 1)",
    );
    final byDive = await repository.getSightingsForDives(['d1']);
    expect(byDive['d1']!.single.amount, (
      abundance: SightingAbundance.exact,
      count: 1,
    ));
    expect((await readBack('d1')).amount, (
      abundance: SightingAbundance.exact,
      count: 1,
    ));
  });

  test('bulk add and bulk replace keep the abundance', () async {
    const many = domain.Sighting(
      id: 'x',
      diveId: '',
      speciesId: '',
      speciesName: '',
      abundance: SightingAbundance.many,
    );
    await repository.bulkAddSightings(
      ['d1'],
      [many.copyWith(speciesId: speciesId)],
    );
    expect((await readBack('d1')).abundance, SightingAbundance.many);

    await repository.bulkReplaceSightings(
      ['d2'],
      [
        many.copyWith(
          speciesId: speciesId,
          abundance: SightingAbundance.exact,
          count: 40,
        ),
      ],
    );
    expect((await readBack('d2')).amount, (
      abundance: SightingAbundance.exact,
      count: 40,
    ));
  });
}
