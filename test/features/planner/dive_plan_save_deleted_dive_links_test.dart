import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

import '../../helpers/test_database.dart';

/// `dive_plans.source_dive_id` (tissue-seeding "plan from this dive") and
/// `dive_plans.linked_dive_id` (plan-vs-actual) both reference `dives` with no
/// ON DELETE action, exactly as `site_id` references `dive_sites`. Under
/// `PRAGMA foreign_keys = ON` saving a plan that names a since-deleted dive
/// fails with SqliteException(787) and the whole save is rolled back, so the
/// diver loses the plan rather than just the link.
///
/// The ids go stale the same way the site id does: deleting a dive clears the
/// columns on plans that are already stored, which leaves an in-memory copy
/// holding a dead id, and `divePlanNotifierProvider` is not auto-disposed, so
/// the planner keeps that copy while the dive is deleted elsewhere. The
/// plan-deleted snackbar's Undo re-saves a captured plan through the same path.
///
/// `savePlan` therefore resolves both dive links as it writes and drops an id
/// that no longer names a row, keeping the plan: a dead link costs the plan its
/// link, never the save. A dead source dive also takes the surface interval
/// that separated the plan from it, as unfollowing the dive does, so the plan
/// is stored as a plain first dive rather than a repetitive one with no dive
/// behind it.
void main() {
  late DivePlanRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: const Value(1000),
          createdAt: const Value(1000),
          updatedAt: const Value(1000),
        ),
      );

  Future<void> deleteDive(String id) =>
      (db.delete(db.dives)..where((t) => t.id.equals(id))).go();

  domain.DivePlan planLinking({
    String? sourceDiveId,
    String? linkedDiveId,
    Duration? surfaceInterval,
  }) => domain.DivePlan(
    id: 'plan-1',
    name: 'Reef dive',
    gfLow: 30,
    gfHigh: 70,
    sourceDiveId: sourceDiveId,
    linkedDiveId: linkedDiveId,
    surfaceInterval: surfaceInterval,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test(
    'savePlan stores a plan whose source dive was deleted, without the link',
    () async {
      await seedDive('dive-1');
      final plan = planLinking(sourceDiveId: 'dive-1');

      // The plan is still only in memory, so nothing references the dive and
      // it deletes cleanly. This is the planner's own case: a dive followed by
      // a never-saved plan, deleted from the dive log before the save.
      await deleteDive('dive-1');

      await repository.savePlan(plan);

      final loaded = await repository.getPlan('plan-1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Reef dive');
      expect(loaded.sourceDiveId, isNull);
    },
  );

  test(
    'savePlan stores a plan whose linked dive was deleted, without the link',
    () async {
      await seedDive('dive-1');
      final plan = planLinking(linkedDiveId: 'dive-1');
      await deleteDive('dive-1');

      await repository.savePlan(plan);

      final loaded = await repository.getPlan('plan-1');
      expect(loaded, isNotNull);
      expect(loaded!.linkedDiveId, isNull);
    },
  );

  test(
    'savePlan returns the plan it stored, with both dead links dropped',
    () async {
      await seedDive('dive-1');
      await seedDive('dive-2');
      final plan = planLinking(sourceDiveId: 'dive-1', linkedDiveId: 'dive-2');
      await deleteDive('dive-1');
      await deleteDive('dive-2');

      final stored = await repository.savePlan(plan);

      expect(stored.sourceDiveId, isNull);
      expect(stored.linkedDiveId, isNull);
    },
  );

  test('savePlan drops only the dead link and keeps the live one', () async {
    await seedDive('dive-1');
    await seedDive('dive-2');
    final plan = planLinking(sourceDiveId: 'dive-1', linkedDiveId: 'dive-2');
    await deleteDive('dive-2');

    final stored = await repository.savePlan(plan);

    expect(stored.sourceDiveId, 'dive-1');
    expect(stored.linkedDiveId, isNull);
    final loaded = await repository.getPlan('plan-1');
    expect(loaded!.sourceDiveId, 'dive-1');
    expect(loaded.linkedDiveId, isNull);
  });

  test('savePlan keeps dive links that still exist', () async {
    await seedDive('dive-1');
    await seedDive('dive-2');

    final stored = await repository.savePlan(
      planLinking(sourceDiveId: 'dive-1', linkedDiveId: 'dive-2'),
    );

    expect(stored.sourceDiveId, 'dive-1');
    expect(stored.linkedDiveId, 'dive-2');
    final loaded = await repository.getPlan('plan-1');
    expect(loaded!.sourceDiveId, 'dive-1');
    expect(loaded.linkedDiveId, 'dive-2');
  });

  test(
    'savePlan drops the surface interval along with a dead source dive',
    () async {
      await seedDive('dive-1');
      final plan = planLinking(
        sourceDiveId: 'dive-1',
        surfaceInterval: const Duration(hours: 2),
      );
      await deleteDive('dive-1');

      final stored = await repository.savePlan(plan);

      expect(stored.surfaceInterval, isNull);
      expect((await repository.getPlan('plan-1'))!.surfaceInterval, isNull);
    },
  );

  test('savePlan keeps the surface interval while the source dive exists, '
      'even when the linked dive went', () async {
    await seedDive('dive-1');
    await seedDive('dive-2');
    final plan = planLinking(
      sourceDiveId: 'dive-1',
      linkedDiveId: 'dive-2',
      surfaceInterval: const Duration(hours: 2),
    );
    await deleteDive('dive-2');

    final stored = await repository.savePlan(plan);

    expect(stored.surfaceInterval, const Duration(hours: 2));
    expect(
      (await repository.getPlan('plan-1'))!.surfaceInterval,
      const Duration(hours: 2),
    );
  });

  test('savePlan leaves a plan with no dive links alone', () async {
    final stored = await repository.savePlan(planLinking());

    expect(stored.sourceDiveId, isNull);
    expect(stored.linkedDiveId, isNull);
  });
}
