import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

import '../../../../helpers/foreign_key_census.dart';
import '../../../../helpers/test_database.dart';

/// `dives.site_id` and `dive_plans.site_id` reference `dive_sites` with no ON
/// DELETE action. Under `PRAGMA foreign_keys = ON` a dive logged at a site,
/// or a plan set at one, failed the site's delete with SqliteException(787)
/// (issue #1952), and a merge failed the same way deleting a duplicate a plan
/// was set at.
///
/// The delete keeps those dives and plans with the site cleared, stamped and
/// marked pending, so peers receive the change rather than keeping a link to
/// a site they are about to delete. A merge moves the plans to the survivor,
/// as it already does the dives, and undo moves them back.
void main() {
  late SiteRepository repository;
  late DivePlanRepository planRepository;
  late AppDatabase db;
  const stale = 1000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = SiteRepository();
    planRepository = DivePlanRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedSite(String id) =>
      repository.createSite(domain.DiveSite(id: id, name: id));

  Future<void> seedDive(String id, {required String siteId}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: const Value(stale),
          siteId: Value(siteId),
          createdAt: const Value(stale),
          updatedAt: const Value(stale),
        ),
      );

  /// Saves a plan through the planner, then backdates it, so the delete's
  /// own stamp is what the assertions see.
  Future<void> seedPlan(String id, {required String siteId}) async {
    final created = DateTime(2026, 1, 1);
    await planRepository.savePlan(
      domain.DivePlan(
        id: id,
        name: id,
        createdAt: created,
        updatedAt: created,
        gfLow: 30,
        gfHigh: 70,
        siteId: siteId,
      ),
    );
    await db.customStatement(
      'UPDATE dive_plans SET updated_at = ? WHERE id = ?',
      [stale, id],
    );
  }

  /// Seeding marks rows pending; clear them so the marks the assertions see
  /// are the ones the operation under test wrote.
  Future<void> clearPendingMarks() =>
      db.customStatement('DELETE FROM sync_records');

  Future<QueryRow> rowOf(String table, String id) => db
      .customSelect(
        'SELECT site_id, updated_at FROM $table WHERE id = ?',
        variables: [Variable<String>(id)],
      )
      .getSingle();

  Future<bool> siteExists(String id) async =>
      (await db
              .customSelect(
                'SELECT 1 FROM dive_sites WHERE id = ?',
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

  /// [table]'s row [id] now points at [siteId] (null when cleared), was
  /// stamped past the seed, and is marked pending as [entityType].
  Future<void> expectRelinked(
    String table,
    String entityType,
    String id, {
    String? siteId,
  }) async {
    final row = await rowOf(table, id);
    expect(row.readNullable<String>('site_id'), siteId);
    expect(row.read<int>('updated_at'), greaterThan(stale));
    expect(await pendingCountFor(entityType, id), 1);
  }

  Future<void> expectUntouched(
    String table,
    String entityType,
    String id, {
    required String siteId,
  }) async {
    final row = await rowOf(table, id);
    expect(row.readNullable<String>('site_id'), siteId);
    expect(row.read<int>('updated_at'), stale);
    expect(await pendingCountFor(entityType, id), 0);
  }

  group('deleteSite', () {
    test('clears the site of the dives logged and plans set there, and '
        'leaves other sites\' dives and plans alone', () async {
      await seedSite('site-a');
      await seedSite('site-b');
      await seedDive('dive-a', siteId: 'site-a');
      await seedDive('dive-b', siteId: 'site-b');
      await seedPlan('plan-a', siteId: 'site-a');
      await seedPlan('plan-b', siteId: 'site-b');
      await clearPendingMarks();

      await repository.deleteSite('site-a');

      expect(await siteExists('site-a'), isFalse);
      await expectRelinked('dives', 'dives', 'dive-a');
      await expectRelinked('dive_plans', 'divePlans', 'plan-a');
      await expectUntouched('dives', 'dives', 'dive-b', siteId: 'site-b');
      await expectUntouched(
        'dive_plans',
        'divePlans',
        'plan-b',
        siteId: 'site-b',
      );
    });

    test('without the media cascade clears the links too', () async {
      await seedSite('site-a');
      await seedDive('dive-a', siteId: 'site-a');
      await seedPlan('plan-a', siteId: 'site-a');
      await clearPendingMarks();

      await repository.deleteSite('site-a', cascadeMedia: false);

      expect(await siteExists('site-a'), isFalse);
      await expectRelinked('dives', 'dives', 'dive-a');
      await expectRelinked('dive_plans', 'divePlans', 'plan-a');
    });

    test('tells saved-plan watchers the plans changed', () async {
      await seedSite('site-a');
      await seedPlan('plan-a', siteId: 'site-a');
      // The saved-plans list refreshes on `dive_plans` table updates, which
      // Drift only reports for writes that name the table.
      final updated = db
          .tableUpdates(TableUpdateQuery.onTable(db.divePlans))
          .first
          .timeout(const Duration(seconds: 5));

      await repository.deleteSite('site-a');

      await expectLater(updated, completes);
    });

    test('that fails leaves the dives and plans linked', () async {
      await seedSite('site-a');
      await seedDive('dive-a', siteId: 'site-a');
      await seedPlan('plan-a', siteId: 'site-a');
      await clearPendingMarks();
      // Stands in for any failure of the site delete itself: the clearing
      // shares its transaction, so it must roll back with it.
      await db.customStatement(
        'CREATE TEMP TRIGGER fail_site_delete BEFORE DELETE ON dive_sites '
        "BEGIN SELECT RAISE(ABORT, 'site delete failed'); END",
      );

      await expectLater(repository.deleteSite('site-a'), throwsA(anything));

      expect(await siteExists('site-a'), isTrue);
      await expectUntouched('dives', 'dives', 'dive-a', siteId: 'site-a');
      await expectUntouched(
        'dive_plans',
        'divePlans',
        'plan-a',
        siteId: 'site-a',
      );
    });
  });

  test('bulkDeleteSites clears every dive and plan at any of the sites, and '
      'leaves those at surviving sites alone', () async {
    await seedSite('site-a');
    await seedSite('site-b');
    await seedSite('site-c');
    await seedDive('dive-a', siteId: 'site-a');
    await seedDive('dive-c', siteId: 'site-c');
    await seedPlan('plan-b', siteId: 'site-b');
    await seedPlan('plan-c', siteId: 'site-c');
    await clearPendingMarks();

    await repository.bulkDeleteSites(['site-a', 'site-b']);

    expect(await siteExists('site-a'), isFalse);
    expect(await siteExists('site-b'), isFalse);
    await expectRelinked('dives', 'dives', 'dive-a');
    await expectRelinked('dive_plans', 'divePlans', 'plan-b');
    await expectUntouched('dives', 'dives', 'dive-c', siteId: 'site-c');
    await expectUntouched(
      'dive_plans',
      'divePlans',
      'plan-c',
      siteId: 'site-c',
    );
  });

  test('mergeSites moves the plans set at a duplicate to the survivor, and '
      'undoMerge moves them back', () async {
    await seedSite('keep');
    await seedSite('lose');
    await seedPlan('plan-keep', siteId: 'keep');
    await seedPlan('plan-lose', siteId: 'lose');
    await clearPendingMarks();

    final snapshot = await repository.mergeSites(
      mergedSite: const domain.DiveSite(id: 'keep', name: 'keep'),
      siteIds: ['keep', 'lose'],
    );

    expect(await siteExists('lose'), isFalse);
    await expectRelinked(
      'dive_plans',
      'divePlans',
      'plan-lose',
      siteId: 'keep',
    );
    await expectUntouched(
      'dive_plans',
      'divePlans',
      'plan-keep',
      siteId: 'keep',
    );
    expect(snapshot!.planOriginalSiteIds, {'plan-lose': 'lose'});

    await db.customStatement(
      'UPDATE dive_plans SET updated_at = ? WHERE id = ?',
      [stale, 'plan-lose'],
    );
    await clearPendingMarks();

    await repository.undoMerge(snapshot);

    expect(await siteExists('lose'), isTrue);
    await expectRelinked(
      'dive_plans',
      'divePlans',
      'plan-lose',
      siteId: 'lose',
    );
  });

  group('site links', () {
    test('getSiteUsage counts every dive and plan at the sites, excluded and '
        'planned dives included, and nothing at other sites', () async {
      await seedSite('site-a');
      await seedSite('site-b');
      await seedSite('site-c');
      await seedDive('dive-a', siteId: 'site-a');
      await seedDive('dive-hidden', siteId: 'site-b');
      await db.customStatement(
        'UPDATE dives SET excluded_from_stats = 1, is_planned = 1 '
        "WHERE id = 'dive-hidden'",
      );
      await seedDive('dive-c', siteId: 'site-c');
      await seedPlan('plan-b', siteId: 'site-b');
      await seedPlan('plan-c', siteId: 'site-c');

      final usage = await repository.getSiteUsage(['site-a', 'site-b']);

      expect(usage.dives, 2);
      expect(usage.plans, 1);
      expect((await repository.getSiteUsage([])).dives, 0);
    });

    test('bulkDeleteSites returns the links it cleared, with the time it '
        'stamped them', () async {
      await seedSite('site-a');
      await seedSite('site-b');
      await seedSite('site-c');
      await seedDive('dive-a', siteId: 'site-a');
      await seedDive('dive-c', siteId: 'site-c');
      await seedPlan('plan-b', siteId: 'site-b');

      final links = await repository.bulkDeleteSites(['site-a', 'site-b']);

      expect(links.diveSiteIds, {'dive-a': 'site-a'});
      expect(links.planSiteIds, {'plan-b': 'site-b'});
      expect(
        links.clearedAt,
        (await rowOf('dives', 'dive-a')).read<int>('updated_at'),
      );
    });

    test('restoreSiteLinks points the dives and plans a bulk delete cleared '
        'back at their re-created sites', () async {
      await seedSite('site-a');
      await seedSite('site-b');
      await seedDive('dive-a', siteId: 'site-a');
      await seedPlan('plan-b', siteId: 'site-b');
      final links = await repository.bulkDeleteSites(['site-a', 'site-b']);
      await seedSite('site-a');
      await seedSite('site-b');
      await clearPendingMarks();

      await repository.restoreSiteLinks(links);

      await expectRelinked('dives', 'dives', 'dive-a', siteId: 'site-a');
      await expectRelinked(
        'dive_plans',
        'divePlans',
        'plan-b',
        siteId: 'site-b',
      );
    });

    test('restoreSiteLinks leaves a dive given another site since, and skips '
        'one deleted since', () async {
      await seedSite('site-a');
      await seedSite('site-other');
      await seedDive('dive-moved', siteId: 'site-a');
      await seedDive('dive-gone', siteId: 'site-a');
      final links = await repository.bulkDeleteSites(['site-a']);
      await seedSite('site-a');
      await db.customStatement(
        "UPDATE dives SET site_id = 'site-other', updated_at = ? "
        "WHERE id = 'dive-moved'",
        [stale],
      );
      await db.customStatement("DELETE FROM dives WHERE id = 'dive-gone'");
      await clearPendingMarks();

      await repository.restoreSiteLinks(links);

      await expectUntouched(
        'dives',
        'dives',
        'dive-moved',
        siteId: 'site-other',
      );
      expect(await pendingCountFor('dives', 'dive-gone'), 0);
    });

    test('restoreSiteLinks leaves a dive or plan edited since the delete, '
        'even one still without a site', () async {
      await seedSite('site-a');
      await seedDive('dive-a', siteId: 'site-a');
      await seedPlan('plan-a', siteId: 'site-a');
      final links = await repository.bulkDeleteSites(['site-a']);
      await seedSite('site-a');
      // Saved again after the delete, with no site: a newer choice the
      // undo must not overwrite.
      for (final table in ['dives', 'dive_plans']) {
        await db.customStatement(
          'UPDATE $table SET updated_at = updated_at + 1',
        );
      }
      await clearPendingMarks();

      await repository.restoreSiteLinks(links);

      expect(
        (await rowOf('dives', 'dive-a')).readNullable<String>('site_id'),
        isNull,
      );
      expect(
        (await rowOf('dive_plans', 'plan-a')).readNullable<String>('site_id'),
        isNull,
      );
      expect(await pendingCountFor('dives', 'dive-a'), 0);
      expect(await pendingCountFor('divePlans', 'plan-a'), 0);
    });
  });

  test('every reference to dive_sites is cascaded or nulled by the schema, or '
      'cleared by the site delete and moved by the merge', () async {
    // Adding a column with a plain `REFERENCES dive_sites(id)` re-breaks the
    // delete and merge of any site a row of it points at. This fails until
    // the column gets an ON DELETE action, or a step in both and a place
    // here.
    expect(await blockingReferencesTo(db, 'dive_sites'), [
      'dive_plans.site_id',
      'dives.site_id',
    ]);
  });
}
