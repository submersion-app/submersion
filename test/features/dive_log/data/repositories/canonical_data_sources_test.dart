import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();

    final now = DateTime.now().millisecondsSinceEpoch;

    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    for (final (id, name) in [
      ('dc-a', 'Kiyans Teric'),
      ('dc-b', 'Erics Teric'),
    ]) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              name: Value(name),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('getDataSources returns one row per computer, even when more than one '
      'dive_data_sources row shares a computerId', () async {
    // Mirrors what a same-computer sequential merge produces
    // (dive_merge_service.dart step 10 carries over every original dive's
    // data source row as provenance; two originals logged by the same
    // physical computer both had their own row).
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-primary'),
            diveId: const Value('dive-1'),
            computerId: const Value('dc-a'),
            isPrimary: const Value(true),
            importedAt: Value(DateTime(2026, 1, 1)),
            createdAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-dup'),
            diveId: const Value('dive-1'),
            computerId: const Value('dc-a'),
            isPrimary: const Value(false),
            importedAt: Value(DateTime(2026, 1, 2)),
            createdAt: Value(DateTime(2026, 1, 2)),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-b'),
            diveId: const Value('dive-1'),
            computerId: const Value('dc-b'),
            isPrimary: const Value(false),
            importedAt: Value(DateTime(2026, 1, 3)),
            createdAt: Value(DateTime(2026, 1, 3)),
          ),
        );

    final sources = await repository.getDataSources('dive-1');

    expect(sources.map((s) => s.id).toList(), ['src-primary', 'src-b']);
  });

  test(
    'getDataSources keeps every source when no two share a computerId',
    () async {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-a'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-a'),
              isPrimary: const Value(true),
              importedAt: Value(DateTime(2026, 1, 1)),
              createdAt: Value(DateTime(2026, 1, 1)),
            ),
          );
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-b'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-b'),
              isPrimary: const Value(false),
              importedAt: Value(DateTime(2026, 1, 2)),
              createdAt: Value(DateTime(2026, 1, 2)),
            ),
          );

      final sources = await repository.getDataSources('dive-1');

      expect(sources.map((s) => s.id).toList(), ['src-a', 'src-b']);
    },
  );
}
