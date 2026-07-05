import 'package:drift/drift.dart' hide isNull, isNotNull;
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
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-2'),
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
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  var profileRowCounter = 0;
  Future<void> insertProfileRow({
    required String diveId,
    required int timestamp,
    required double depth,
    required String? computerId,
    required bool isPrimary,
  }) async {
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion(
            id: Value('prof-${profileRowCounter++}'),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            timestamp: Value(timestamp),
            depth: Value(depth),
          ),
        );
  }

  test('null-computerId rows attribute to the primary source', () async {
    await insertProfileRow(
      diveId: 'dive-1',
      timestamp: 0,
      depth: 10.0,
      computerId: null,
      isPrimary: true,
    );
    await insertProfileRow(
      diveId: 'dive-1',
      timestamp: 10,
      depth: 12.0,
      computerId: 'dc-b',
      isPrimary: false,
    );

    final result = await repository.getProfilesByDataSource('dive-1');

    expect(result.keys.toList(), ['src-a', 'src-b']);
    expect(result['src-a']!.points.single.depth, 10.0);
    expect(result['src-a']!.isEdited, false);
    expect(result['src-b']!.points.single.depth, 12.0);
    expect(result['src-b']!.computerId, 'dc-b');
  });

  test(
    'rows with a computerId matching no source fall back to primary',
    () async {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: const Value('dc-orphan'),
              name: const Value('Orphan'),
              createdAt: Value(DateTime.now().millisecondsSinceEpoch),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
      await insertProfileRow(
        diveId: 'dive-1',
        timestamp: 0,
        depth: 10.0,
        computerId: 'dc-a',
        isPrimary: true,
      );
      await insertProfileRow(
        diveId: 'dive-1',
        timestamp: 5,
        depth: 11.0,
        computerId: 'dc-orphan',
        isPrimary: false,
      );

      final result = await repository.getProfilesByDataSource('dive-1');

      expect(result['src-a']!.points.length, 2);
    },
  );

  test('edited profile replaces primary rows and sets isEdited', () async {
    // Original primary rows demoted to isPrimary=false, edited rows
    // isPrimary=true with computerId NULL (the edit-flow convention).
    await insertProfileRow(
      diveId: 'dive-1',
      timestamp: 0,
      depth: 10.0,
      computerId: 'dc-a',
      isPrimary: false,
    );
    await insertProfileRow(
      diveId: 'dive-1',
      timestamp: 0,
      depth: 9.5,
      computerId: null,
      isPrimary: true,
    );
    await insertProfileRow(
      diveId: 'dive-1',
      timestamp: 0,
      depth: 12.0,
      computerId: 'dc-b',
      isPrimary: false,
    );

    final result = await repository.getProfilesByDataSource('dive-1');

    expect(result['src-a']!.isEdited, true);
    expect(result['src-a']!.points.single.depth, 9.5);
    expect(result['src-b']!.points.single.depth, 12.0);
    expect(result['src-b']!.isEdited, false);
  });

  test('metadata-only sources keep an entry with no points', () async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-meta'),
            diveId: const Value('dive-1'),
            isPrimary: const Value(false),
            importedAt: Value(DateTime(2026, 1, 3)),
            createdAt: Value(DateTime(2026, 1, 3)),
          ),
        );
    await insertProfileRow(
      diveId: 'dive-1',
      timestamp: 0,
      depth: 10.0,
      computerId: 'dc-a',
      isPrimary: true,
    );

    final result = await repository.getProfilesByDataSource('dive-1');

    expect(result.keys, containsAll(['src-a', 'src-b', 'src-meta']));
    expect(result['src-meta']!.points, isEmpty);
  });

  test('returns empty map when the dive has no data source rows', () async {
    await insertProfileRow(
      diveId: 'dive-2',
      timestamp: 0,
      depth: 8.0,
      computerId: null,
      isPrimary: true,
    );

    final result = await repository.getProfilesByDataSource('dive-2');

    expect(result, isEmpty);
  });
}
