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
