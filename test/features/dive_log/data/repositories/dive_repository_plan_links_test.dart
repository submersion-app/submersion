import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// `dive_plans.source_dive_id` ("plan from this dive") and `linked_dive_id`
/// (plan-vs-actual) reference `dives` with no ON DELETE action. Under
/// `PRAGMA foreign_keys = ON` a plan pointing at a dive failed the dive's
/// delete with SqliteException(787), so the dive could not be deleted, and
/// neither could the merge, consolidation or import rollback that deletes
/// dives through the same methods.
///
/// The delete clears those links, stamps each plan and marks it pending, so
/// peers receive the cleared plan rather than keeping a link to a dive they
/// are about to delete.
void main() {
  late DiveRepository repository;
  late DivePlanRepository planRepository;
  late AppDatabase db;
  const stale = 1000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    planRepository = DivePlanRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDive(String id) => repository.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1)),
  );

  /// Saves a plan through the planner, then backdates it and clears the
  /// pending marks the seeding left, so the delete's own stamp and mark are
  /// what the assertions see.
  Future<void> seedPlan(
    String id, {
    String? sourceDiveId,
    String? linkedDiveId,
  }) async {
    final created = DateTime(2026, 1, 1);
    await planRepository.savePlan(
      domain.DivePlan(
        id: id,
        name: id,
        createdAt: created,
        updatedAt: created,
        gfLow: 30,
        gfHigh: 70,
        sourceDiveId: sourceDiveId,
        linkedDiveId: linkedDiveId,
      ),
    );
    await db.customStatement(
      'UPDATE dive_plans SET updated_at = ? WHERE id = ?',
      [stale, id],
    );
  }

  Future<void> clearPendingMarks() =>
      db.customStatement('DELETE FROM sync_records');

  Future<QueryRow> planRow(String id) => db
      .customSelect(
        'SELECT source_dive_id, linked_dive_id, updated_at FROM dive_plans '
        'WHERE id = ?',
        variables: [Variable<String>(id)],
      )
      .getSingle();

  Future<bool> diveExists(String id) async =>
      (await db
              .customSelect(
                'SELECT 1 FROM dives WHERE id = ?',
                variables: [Variable<String>(id)],
              )
              .get())
          .isNotEmpty;

  Future<int> pendingCountFor(String entityType, String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? '
                "AND record_id = ? AND sync_status = 'pending'",
                variables: [
                  Variable<String>(entityType),
                  Variable<String>(recordId),
                ],
              )
              .getSingle())
          .read<int>('n');

  Future<void> expectCleared(String planId) async {
    final plan = await planRow(planId);
    expect(plan.readNullable<String>('source_dive_id'), isNull);
    expect(plan.readNullable<String>('linked_dive_id'), isNull);
    expect(plan.read<int>('updated_at'), greaterThan(stale));
    expect(await pendingCountFor('divePlans', planId), 1);
  }

  Future<void> expectUntouched(String planId, {required String diveId}) async {
    final plan = await planRow(planId);
    expect(plan.readNullable<String>('source_dive_id'), diveId);
    expect(plan.readNullable<String>('linked_dive_id'), diveId);
    expect(plan.read<int>('updated_at'), stale);
    expect(await pendingCountFor('divePlans', planId), 0);
  }

  test('deleteDive clears the links of a plan built from and linked to the '
      'dive, and leaves plans on other dives alone', () async {
    await seedDive('dive-a');
    await seedDive('dive-b');
    await seedPlan('plan-a', sourceDiveId: 'dive-a', linkedDiveId: 'dive-a');
    await seedPlan('plan-b', sourceDiveId: 'dive-b', linkedDiveId: 'dive-b');
    await clearPendingMarks();

    await repository.deleteDive('dive-a');

    expect(await diveExists('dive-a'), isFalse);
    await expectCleared('plan-a');
    await expectUntouched('plan-b', diveId: 'dive-b');
  });

  test('deleteDive without the media cascade (merge undo) clears the links '
      'too', () async {
    await seedDive('dive-a');
    await seedPlan('plan-a', sourceDiveId: 'dive-a', linkedDiveId: 'dive-a');
    await clearPendingMarks();

    await repository.deleteDive('dive-a', cascadeMedia: false);

    expect(await diveExists('dive-a'), isFalse);
    await expectCleared('plan-a');
  });

  test('bulkDeleteDives clears every plan linked to any of the dives, and '
      'leaves plans on surviving dives alone', () async {
    await seedDive('dive-a');
    await seedDive('dive-b');
    await seedDive('dive-c');
    // One plan per column and one spanning both dives, so a link is cleared
    // whichever column carries it and a plan touching two doomed dives is
    // marked once.
    await seedPlan('plan-source', sourceDiveId: 'dive-a');
    await seedPlan('plan-linked', linkedDiveId: 'dive-b');
    await seedPlan('plan-both', sourceDiveId: 'dive-a', linkedDiveId: 'dive-b');
    await seedPlan('plan-c', sourceDiveId: 'dive-c', linkedDiveId: 'dive-c');
    await clearPendingMarks();

    await repository.bulkDeleteDives(['dive-a', 'dive-b']);

    expect(await diveExists('dive-a'), isFalse);
    expect(await diveExists('dive-b'), isFalse);
    await expectCleared('plan-source');
    await expectCleared('plan-linked');
    await expectCleared('plan-both');
    await expectUntouched('plan-c', diveId: 'dive-c');
  });

  test('every reference to dives is cascaded or nulled by the schema, or '
      'cleared by the dive delete', () async {
    // Adding a column with a plain `REFERENCES dives(id)` re-breaks the
    // delete of any dive a row of it points at. This fails until the column
    // gets an ON DELETE action, or a step in the dive delete and a place
    // here.
    const clearedByDelete = [
      'dive_plans.linked_dive_id',
      'dive_plans.source_dive_id',
    ];
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final blocking = <String>[];
    for (final row in tables) {
      final table = row.read<String>('name');
      final keys = await db
          .customSelect("PRAGMA foreign_key_list('$table')")
          .get();
      for (final k in keys) {
        final action = k.read<String>('on_delete').toUpperCase();
        if (k.read<String>('table') == 'dives' &&
            action != 'CASCADE' &&
            action != 'SET NULL') {
          blocking.add('$table.${k.read<String>('from')}');
        }
      }
    }
    expect(blocking..sort(), clearedByDelete);
  });
}
