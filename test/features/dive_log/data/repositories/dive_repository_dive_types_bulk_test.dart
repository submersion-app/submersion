import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<List<String>> typesOf(String id) async =>
      (await repository.getDiveById(id))!.diveTypeIds.toList()..sort();

  Future<void> seed(String id, List<String> t) => repository.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), diveTypeIds: t),
  );

  test('replace sets exactly the given types and representative', () async {
    await seed('d1', ['shore']);
    await repository.bulkReplaceDiveTypes(['d1'], ['cave', 'deep']);
    expect(await typesOf('d1'), ['cave', 'deep']);
    expect((await db.select(db.dives).getSingle()).diveType, 'cave');
  });

  test('add unions without dropping existing', () async {
    await seed('d1', ['shore']);
    await repository.bulkAddDiveTypes(['d1'], ['wreck']);
    expect(await typesOf('d1'), ['shore', 'wreck']);
  });

  test('add is idempotent (no duplicate rows)', () async {
    await seed('d1', ['shore']);
    await repository.bulkAddDiveTypes(['d1'], ['shore', 'wreck']);
    expect(await typesOf('d1'), ['shore', 'wreck']);
  });

  test('remove drops the given types', () async {
    await seed('d1', ['shore', 'wreck']);
    await repository.bulkRemoveDiveTypes(['d1'], ['wreck']);
    expect(await typesOf('d1'), ['shore']);
  });

  test('remove that would empty a dive falls back to recreational', () async {
    await seed('d1', ['shore']);
    await repository.bulkRemoveDiveTypes(['d1'], ['shore']);
    expect(await typesOf('d1'), ['recreational']);
  });

  test('bulk ops apply across multiple dives and skip others', () async {
    await seed('d1', ['shore']);
    await seed('d2', ['boat']);
    await seed('d3', ['cave']);
    await repository.bulkAddDiveTypes(['d1', 'd2'], ['night']);
    expect(await typesOf('d1'), ['night', 'shore']);
    expect(await typesOf('d2'), ['boat', 'night']);
    expect(await typesOf('d3'), ['cave']); // untouched
  });

  test('bulk add seeds from the representative column for a legacy dive', () async {
    await seed('d1', ['shore']);
    // Simulate a legacy/old-version dive: only dives.dive_type, no junction rows.
    await (db.delete(
      db.diveDiveTypes,
    )..where((t) => t.diveId.equals('d1'))).go();

    await repository.bulkAddDiveTypes(['d1'], ['wreck']);
    // Without seeding from the column, the representative 'shore' would be lost.
    expect(await typesOf('d1'), ['shore', 'wreck']);
  });

  test(
    'bulk remove seeds from the representative column for a legacy dive',
    () async {
      await seed('d1', ['shore', 'wreck']);
      await (db.delete(
        db.diveDiveTypes,
      )..where((t) => t.diveId.equals('d1'))).go();

      await repository.bulkRemoveDiveTypes(['d1'], ['wreck']);
      // Seeded from the representative 'shore'; removing absent 'wreck' keeps it
      // instead of falling back to recreational.
      expect(await typesOf('d1'), ['shore']);
    },
  );
}
