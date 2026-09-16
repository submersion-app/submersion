import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';

import '../../../../helpers/foreign_key_census.dart';
import '../../../../helpers/test_database.dart';

/// `dives.dive_center_id` references `dive_centers` with no ON DELETE
/// action. Under `PRAGMA foreign_keys = ON` a dive logged with a center
/// failed the center's delete with SqliteException(787) (issue #1952).
///
/// The delete keeps those dives with the center cleared, stamped and marked
/// pending, so peers receive the change rather than keeping a link to a
/// center they are about to delete.
void main() {
  late DiveCenterRepository repository;
  late AppDatabase db;
  const stale = 1000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveCenterRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedCenter(String id) => db
      .into(db.diveCenters)
      .insert(
        DiveCentersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(stale),
          updatedAt: const Value(stale),
        ),
      );

  Future<void> seedDive(String id, {required String centerId}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: const Value(stale),
          diveCenterId: Value(centerId),
          createdAt: const Value(stale),
          updatedAt: const Value(stale),
        ),
      );

  Future<QueryRow> diveRow(String id) => db
      .customSelect(
        'SELECT dive_center_id, updated_at FROM dives WHERE id = ?',
        variables: [Variable<String>(id)],
      )
      .getSingle();

  Future<bool> centerExists(String id) async =>
      (await db
              .customSelect(
                'SELECT 1 FROM dive_centers WHERE id = ?',
                variables: [Variable<String>(id)],
              )
              .get())
          .isNotEmpty;

  Future<int> pendingCountFor(String recordId) async =>
      (await db
              .customSelect(
                "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = "
                "'dives' AND record_id = ? AND sync_status = 'pending'",
                variables: [Variable<String>(recordId)],
              )
              .getSingle())
          .read<int>('n');

  Future<void> expectUntouched(
    String diveId, {
    required String centerId,
  }) async {
    final dive = await diveRow(diveId);
    expect(dive.readNullable<String>('dive_center_id'), centerId);
    expect(dive.read<int>('updated_at'), stale);
    expect(await pendingCountFor(diveId), 0);
  }

  test('deleteDiveCenter clears the center of the dives logged with it, and '
      'leaves other centers\' dives alone', () async {
    await seedCenter('center-a');
    await seedCenter('center-b');
    await seedDive('dive-a', centerId: 'center-a');
    await seedDive('dive-b', centerId: 'center-b');

    await repository.deleteDiveCenter('center-a');

    expect(await centerExists('center-a'), isFalse);
    final dive = await diveRow('dive-a');
    expect(dive.readNullable<String>('dive_center_id'), isNull);
    expect(dive.read<int>('updated_at'), greaterThan(stale));
    expect(await pendingCountFor('dive-a'), 1);
    await expectUntouched('dive-b', centerId: 'center-b');
  });

  test('deleteDiveCenter tells dive-list watchers the dives changed', () async {
    await seedCenter('center-a');
    await seedDive('dive-a', centerId: 'center-a');
    // The dive lists refresh on `dives` table updates, which Drift only
    // reports for writes that name the table.
    final updated = db
        .tableUpdates(TableUpdateQuery.onTable(db.dives))
        .first
        .timeout(const Duration(seconds: 5));

    await repository.deleteDiveCenter('center-a');

    await expectLater(updated, completes);
  });

  test('deleteDiveCenter that fails leaves the dives linked', () async {
    await seedCenter('center-a');
    await seedDive('dive-a', centerId: 'center-a');
    // Stands in for any failure of the center delete itself: the clearing
    // shares its transaction, so it must roll back with it.
    await db.customStatement(
      'CREATE TEMP TRIGGER fail_center_delete BEFORE DELETE ON dive_centers '
      "BEGIN SELECT RAISE(ABORT, 'center delete failed'); END",
    );

    await expectLater(
      repository.deleteDiveCenter('center-a'),
      throwsA(anything),
    );

    expect(await centerExists('center-a'), isTrue);
    await expectUntouched('dive-a', centerId: 'center-a');
  });

  test('getLinkedDiveCount counts every dive logged with the centers, '
      'excluded and planned dives included', () async {
    await seedCenter('center-a');
    await seedCenter('center-b');
    await seedCenter('center-c');
    await seedDive('dive-a', centerId: 'center-a');
    await seedDive('dive-hidden', centerId: 'center-b');
    await db.customStatement(
      'UPDATE dives SET excluded_from_stats = 1, is_planned = 1 '
      "WHERE id = 'dive-hidden'",
    );
    await seedDive('dive-c', centerId: 'center-c');

    expect(await repository.getLinkedDiveCount(['center-a', 'center-b']), 2);
    expect(await repository.getLinkedDiveCount(['center-c']), 1);
    expect(await repository.getLinkedDiveCount([]), 0);
  });

  test('every reference to dive_centers is cascaded or nulled by the schema, '
      'or cleared by the center delete', () async {
    // Adding a column with a plain `REFERENCES dive_centers(id)` re-breaks
    // the delete of any center a row of it points at. This fails until the
    // column gets an ON DELETE action, or a step in the delete and a place
    // here.
    expect(await blockingReferencesTo(db, 'dive_centers'), [
      'dives.dive_center_id',
    ]);
  });
}
