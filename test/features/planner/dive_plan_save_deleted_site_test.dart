import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

import '../../helpers/test_database.dart';

/// `dive_plans.site_id` references `dive_sites` with no ON DELETE action and
/// the database runs with `PRAGMA foreign_keys = ON`, so saving a plan whose
/// site has since been deleted failed with SqliteException(787) and the plan
/// was not saved at all (issue #1985).
///
/// The planner holds the site id in memory, so it goes stale whenever a site
/// is deleted while a plan that names it is still being edited, re-saved by
/// the plan-deleted snackbar's Undo, or duplicated. `savePlan` therefore
/// resolves the site as it writes and drops an id that no longer names a row,
/// and hands the caller back the plan it actually stored.
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

  Future<void> seedSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(1000),
          updatedAt: const Value(1000),
        ),
      );

  domain.DivePlan planAt(String? siteId) => domain.DivePlan(
    id: 'plan-1',
    name: 'Reef dive',
    gfLow: 30,
    gfHigh: 70,
    siteId: siteId,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test(
    'savePlan stores a plan whose site was deleted, without the site',
    () async {
      await seedSite('site-1');
      final plan = planAt('site-1');

      // The plan is still only in memory, so nothing references the site and it
      // deletes cleanly. This is the planner's own case: a site picked for a
      // never-saved plan, deleted from the Sites screen before the save.
      await (db.delete(db.diveSites)..where((t) => t.id.equals('site-1'))).go();

      await repository.savePlan(plan);

      final loaded = await repository.getPlan('plan-1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Reef dive');
      expect(loaded.siteId, isNull);
    },
  );

  test(
    'savePlan returns the plan it stored, with the dead site dropped',
    () async {
      await seedSite('site-1');
      await (db.delete(db.diveSites)..where((t) => t.id.equals('site-1'))).go();

      final stored = await repository.savePlan(planAt('site-1'));

      expect(stored.siteId, isNull);
    },
  );

  test('savePlan keeps a site that still exists', () async {
    await seedSite('site-1');

    final stored = await repository.savePlan(planAt('site-1'));

    expect(stored.siteId, 'site-1');
    expect((await repository.getPlan('plan-1'))!.siteId, 'site-1');
  });

  test('savePlan leaves a plan with no site alone', () async {
    final stored = await repository.savePlan(planAt(null));

    expect(stored.siteId, isNull);
    expect((await repository.getPlan('plan-1'))!.siteId, isNull);
  });

  test(
    'savePlan returns the persisted updatedAt, not the submitted one',
    () async {
      // The row is stamped with the save's own clock, so a returned plan still
      // carrying the submitted timestamp would not be "the plan as stored" and
      // a caller comparing it against the row would silently disagree.
      final stored = await repository.savePlan(planAt(null));
      final loaded = await repository.getPlan('plan-1');

      expect(stored.updatedAt, loaded!.updatedAt);
      expect(stored.updatedAt, isNot(DateTime(2026, 1, 1)));
      expect(stored.createdAt, loaded.createdAt);
    },
  );
}
