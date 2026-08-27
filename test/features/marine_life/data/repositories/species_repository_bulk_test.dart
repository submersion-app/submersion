import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late SpeciesRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = SpeciesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.Sighting s(String speciesId, {int count = 1}) => domain.Sighting(
    id: '',
    diveId: '',
    speciesId: speciesId,
    speciesName: '',
    count: count,
  );

  test('bulkAddSightings inserts a sighting per dive per template', () async {
    await repository.bulkAddSightings(['d1', 'd2'], [s('turtle', count: 2)]);
    final d1 = await (db.select(
      db.sightings,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(d1.single.speciesId, 'turtle');
    expect(d1.single.count, 2);
    final d2 = await (db.select(
      db.sightings,
    )..where((t) => t.diveId.equals('d2'))).get();
    expect(d2.length, 1);
  });

  test('bulkReplaceSightings overwrites per dive', () async {
    await repository.bulkAddSightings(['d1'], [s('turtle')]);
    await repository.bulkReplaceSightings(['d1'], [s('shark')]);
    final rows = await (db.select(
      db.sightings,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(rows.single.speciesId, 'shark');
  });
}
