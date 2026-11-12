import 'package:drift/drift.dart' show OrderingTerm;
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

  test(
    'createDive persists the full type set and representative column',
    () async {
      await repository.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime(2026, 1, 1),
          diveTypeIds: const ['shore', 'wreck', 'night'],
        ),
      );

      final rows = await (db.select(
        db.diveDiveTypes,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.map((r) => r.diveTypeId).toSet(), {
        'shore',
        'wreck',
        'night',
      });

      final dive = await db.select(db.dives).getSingle();
      expect(dive.diveType, 'shore'); // representative = first

      final loaded = await repository.getDiveById('d1');
      expect(loaded!.diveTypeIds, ['shore', 'wreck', 'night']);
    },
  );

  test('updateDive replaces the type set and representative', () async {
    await repository.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 1),
        diveTypeIds: const ['shore'],
      ),
    );
    final dive = (await repository.getDiveById('d1'))!;
    await repository.updateDive(
      dive.copyWith(diveTypeIds: const ['cave', 'deep']),
    );

    final loaded = await repository.getDiveById('d1');
    expect(loaded!.diveTypeIds, ['cave', 'deep']);
    final row = await db.select(db.dives).getSingle();
    expect(row.diveType, 'cave');
  });

  group('updateDive writes only the types that changed (#4477)', () {
    Future<List<DiveDiveType>> typeRows() =>
        (db.select(db.diveDiveTypes)
              ..where((t) => t.diveId.equals('d1'))
              ..orderBy([
                (t) => OrderingTerm(expression: t.createdAt),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();

    Future<domain.Dive> diveWith(List<String> types) async {
      await repository.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime(2026, 1, 1),
          diveTypeIds: types,
        ),
      );
      return (await repository.getDiveById('d1'))!;
    }

    test('an edit that keeps the types leaves their rows alone', () async {
      final dive = await diveWith(const ['shore', 'wreck']);
      final before = await typeRows();

      await repository.updateDive(dive.copyWith(notes: 'Edited'));

      expect(await typeRows(), before);
    });

    test('adding a type keeps the rows of those that stay', () async {
      final dive = await diveWith(const ['shore', 'wreck']);
      final before = {for (final r in await typeRows()) r.diveTypeId: r.id};

      await repository.updateDive(
        dive.copyWith(diveTypeIds: const ['shore', 'wreck', 'night']),
      );

      final after = await typeRows();
      expect(after.map((r) => r.diveTypeId), ['shore', 'wreck', 'night']);
      expect(after[0].id, before['shore']);
      expect(after[1].id, before['wreck']);
      expect((await repository.getDiveById('d1'))!.diveTypeIds, [
        'shore',
        'wreck',
        'night',
      ]);
    });

    test('dropping a type deletes only its row', () async {
      final dive = await diveWith(const ['shore', 'wreck', 'night']);
      final before = {for (final r in await typeRows()) r.diveTypeId: r.id};

      await repository.updateDive(
        dive.copyWith(diveTypeIds: const ['shore', 'night']),
      );

      final after = await typeRows();
      expect(after.map((r) => r.id), [before['shore'], before['night']]);
    });

    test('a new first type becomes the representative', () async {
      final dive = await diveWith(const ['shore', 'wreck']);
      final before = {for (final r in await typeRows()) r.diveTypeId: r.id};

      await repository.updateDive(
        dive.copyWith(diveTypeIds: const ['wreck', 'shore']),
      );

      final after = await typeRows();
      expect(after.map((r) => r.diveTypeId), ['wreck', 'shore']);
      expect(after.map((r) => r.id), [before['wreck'], before['shore']]);
      expect((await db.select(db.dives).getSingle()).diveType, 'wreck');
      expect((await repository.getDiveById('d1'))!.diveTypeIds, [
        'wreck',
        'shore',
      ]);
    });

    test('a type added in front comes first', () async {
      final dive = await diveWith(const ['shore']);

      await repository.updateDive(
        dive.copyWith(diveTypeIds: const ['cave', 'shore']),
      );

      expect((await repository.getDiveById('d1'))!.diveTypeIds, [
        'cave',
        'shore',
      ]);
      expect((await db.select(db.dives).getSingle()).diveType, 'cave');
    });
  });

  test('a dive with no junction rows falls back to the column', () async {
    await repository.createDive(
      domain.Dive(
        id: 'legacy',
        dateTime: DateTime(2026, 1, 1),
        diveTypeIds: const ['drift'],
      ),
    );
    // Simulate a legacy/old-version dive: only dives.dive_type, no junction rows.
    await (db.delete(
      db.diveDiveTypes,
    )..where((t) => t.diveId.equals('legacy'))).go();

    final loaded = await repository.getDiveById('legacy');
    expect(loaded!.diveTypeIds, ['drift']); // hydrated from the column fallback
  });
}
