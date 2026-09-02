import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

import '../../../../helpers/test_database.dart';

/// Deleting a diver nulls the `computer_id` that other divers' dives and
/// data sources still point at, so the DELETE of that diver's computers
/// does not violate the FK.
///
/// Those rows are synced. Clearing them with raw SQL leaves `updated_at`
/// and the HLC where they were and marks nothing pending, so the change
/// never reaches a peer: the peer keeps the old computerId, and its next
/// last-writer-wins update carries that stale reference back. The series
/// tables next to these statements already stamp and mark; these have to
/// as well.
void main() {
  late DiverRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id, {bool isDefault = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            isDefault: Value(isDefault),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion(
            id: Value('settings-$id'),
            diverId: Value(id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<int> pendingCountFor(String entityType, String recordId) async {
    final row = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? "
          "AND record_id = ? AND sync_status = 'pending'",
          variables: [Variable<String>(entityType), Variable<String>(recordId)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  test("a foreign dive's cleared computer is stamped and marked", () async {
    await insertDiver('diver-a');
    await insertDiver('diver-b');
    const stale = 1000;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-a',
            name: 'Perdix',
            diverId: const Value('diver-a'),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
    // Bob's dive, logged against Alice's computer.
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-b',
            diverId: const Value('diver-b'),
            computerId: const Value('comp-a'),
            diveDateTime: stale,
            createdAt: stale,
            updatedAt: stale,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-b',
            diveId: 'dive-b',
            computerId: const Value('comp-a'),
            importedAt: DateTime.fromMillisecondsSinceEpoch(stale),
            createdAt: DateTime.fromMillisecondsSinceEpoch(stale),
          ),
        );

    await repository.deleteDiverWithReassignment('diver-a');

    final dive = await db
        .customSelect(
          "SELECT computer_id, updated_at FROM dives WHERE id = 'dive-b'",
        )
        .getSingle();
    expect(dive.readNullable<String>('computer_id'), isNull);
    expect(
      dive.read<int>('updated_at'),
      greaterThan(stale),
      reason: 'a peer cannot see a change that did not move updated_at',
    );
    expect(await pendingCountFor('dives', 'dive-b'), 1);

    // dive_data_sources carries no updated_at and no hlc: it is a clockless
    // child that syncs with its parent dive (entityHasUpdatedAt is false for
    // it), so what has to move is the parent's pending mark, above.
    final source = await db
        .customSelect(
          "SELECT computer_id FROM dive_data_sources WHERE id = 'src-b'",
        )
        .getSingle();
    expect(source.readNullable<String>('computer_id'), isNull);
  });

  test('a cleared data source marks its own dive pending', () async {
    // The dive itself never referenced the computer, so only the source
    // clear can be what publishes this change.
    await insertDiver('diver-a');
    await insertDiver('diver-b');
    const stale = 1000;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-a',
            name: 'Perdix',
            diverId: const Value('diver-a'),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-c',
            diverId: const Value('diver-b'),
            diveDateTime: stale,
            createdAt: stale,
            updatedAt: stale,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-c',
            diveId: 'dive-c',
            computerId: const Value('comp-a'),
            importedAt: DateTime.fromMillisecondsSinceEpoch(stale),
            createdAt: DateTime.fromMillisecondsSinceEpoch(stale),
          ),
        );

    await repository.deleteDiverWithReassignment('diver-a');

    final source = await db
        .customSelect(
          "SELECT computer_id FROM dive_data_sources WHERE id = 'src-c'",
        )
        .getSingle();
    expect(source.readNullable<String>('computer_id'), isNull);
    expect(await pendingCountFor('dives', 'dive-c'), 1);
  });

  test(
    'a surviving legacy dive_profiles row does not block the delete',
    () async {
      // The v183 rung drops dive_profiles only once its rows have moved into
      // the series table, so a device whose pack threw still carries it, and
      // its computer_id FK has no ON DELETE action. A row of that table on
      // another diver's dive fails `DELETE FROM dive_computers` with
      // SqliteException(787) and rolls the whole delete back, so the diver can
      // never be deleted on that device. DiveComputerRepository.deleteComputer
      // guards the same statement the same way (#823).
      await db.customStatement(
        'CREATE TABLE dive_profiles ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL REFERENCES dives (id) ON DELETE CASCADE, '
        'computer_id TEXT REFERENCES dive_computers (id), '
        'timestamp INTEGER NOT NULL, '
        'depth REAL NOT NULL)',
      );
      await insertDiver('diver-a');
      await insertDiver('diver-b');
      const stale = 1000;
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'comp-a',
              name: 'Perdix',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'dive-b',
              diverId: const Value('diver-b'),
              diveDateTime: stale,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db.customStatement(
        'INSERT INTO dive_profiles (id, dive_id, computer_id, timestamp, depth) '
        'VALUES (?, ?, ?, ?, ?)',
        ['dp-b', 'dive-b', 'comp-a', 0, 1.0],
      );

      await repository.deleteDiverWithReassignment('diver-a');

      expect(
        await db
            .customSelect("SELECT id FROM divers WHERE id = 'diver-a'")
            .get(),
        isEmpty,
      );
      final profile = await db
          .customSelect(
            "SELECT computer_id FROM dive_profiles WHERE id = 'dp-b'",
          )
          .getSingle();
      expect(profile.readNullable<String>('computer_id'), isNull);
    },
  );

  test('a dive of the deleted diver is not marked pending', () async {
    // It is about to be deleted with its diver; marking it pending would
    // publish a row that no longer exists.
    await insertDiver('diver-a');
    const stale = 1000;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-a',
            name: 'Perdix',
            diverId: const Value('diver-a'),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-a',
            diverId: const Value('diver-a'),
            computerId: const Value('comp-a'),
            diveDateTime: stale,
            createdAt: stale,
            updatedAt: stale,
          ),
        );

    await repository.deleteDiverWithReassignment('diver-a');

    expect(await pendingCountFor('dives', 'dive-a'), 0);
  });
}
