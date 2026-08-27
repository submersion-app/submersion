import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'diveProvider auto-refreshes after a direct dives-table write (sync scenario)',
    () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1, maxDepth: 25.0),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // An active listener keeps diveProvider (and its table-change
      // subscription) alive, mirroring the dive detail page watching it.
      final sub = container.listen(diveProvider('d1'), (_, _) {});
      addTearDown(sub.close);

      final initial = await container.read(diveProvider('d1').future);
      expect(initial?.maxDepth, 25.0);

      // A sync applies a remote edit straight to the dives table (no notifier
      // mutation, so no manual ref.invalidate(diveProvider)). The
      // watchDivesChanges tick must invalidate diveProvider so the detail page
      // reflects the synced edit -- exactly what the dive list already does.
      final db = DatabaseService.instance.database;
      await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
        const DivesCompanion(maxDepth: Value(30.0)),
      );

      // Poll until the tick -> invalidateSelf -> rebuild settles.
      double? depth;
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        depth = (await container.read(diveProvider('d1').future))?.maxDepth;
        if (depth == 30.0) break;
      }

      expect(
        depth,
        30.0,
        reason:
            'diveProvider should auto-refresh after a direct dives-table write '
            '(sync) without any manual invalidation, so the dive detail page '
            'reflects synced edits',
      );
    },
  );

  test(
    'diveProfileProvider auto-refreshes after a dive_profiles write (sync)',
    () async {
      // Proves the aggregate watchDiveDetailChanges stream covers a NON-dives
      // table: a synced profile change must refresh the detail page's chart.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(diveProfileProvider('d1'), (_, _) {});
      addTearDown(sub.close);

      final initial = await container.read(diveProfileProvider('d1').future);
      expect(initial, isEmpty);

      final db = DatabaseService.instance.database;
      await db
          .into(db.diveProfiles)
          .insert(
            DiveProfilesCompanion.insert(
              id: 'p1',
              diveId: 'd1',
              timestamp: 0,
              depth: 0.0,
            ),
          );

      var count = 0;
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        count = (await container.read(diveProfileProvider('d1').future)).length;
        if (count == 1) break;
      }
      expect(
        count,
        1,
        reason:
            'diveProfileProvider should auto-refresh after a dive_profiles '
            'write via watchDiveDetailChanges, so the profile chart reflects '
            'synced changes',
      );
    },
  );

  test('diveStatisticsProvider auto-refreshes after a direct dives-table write '
      '(dashboard HeroHeader / issue #217 sync scenario)', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );

    final container = ProviderContainer(
      overrides: [
        // Null current diver => statistics count every dive (no filter).
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // The dashboard HeroHeader keeps diveStatisticsProvider alive by watching
    // it, mirroring an on-screen home tab.
    final sub = container.listen(diveStatisticsProvider, (_, _) {});
    addTearDown(sub.close);

    final initial = await container.read(diveStatisticsProvider.future);
    expect(initial.totalDives, 1);

    // A dive-computer import or an iCloud sync writes a new dive straight to
    // the dives table (no manual invalidation), exactly like the home tab's
    // data source.
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );

    // Poll until the dives-table tick -> invalidate -> rebuild settles.
    int total = initial.totalDives;
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      total = (await container.read(diveStatisticsProvider.future)).totalDives;
      if (total == 2) break;
    }

    expect(
      total,
      2,
      reason:
          'diveStatisticsProvider feeds the dashboard HeroHeader; it must '
          'refresh after a dives-table write (import/sync) so the home tab '
          'stats reflect new dives without an app restart (issue #217).',
    );
  });

  test(
    'watchDiveDetailChanges coalesces a burst of writes into a single tick',
    () async {
      // A sync applies remote changes as MANY per-changeset transactions, each
      // committing separately and firing its own Drift table-update tick. Left
      // un-coalesced, every tick re-invalidates the 15 per-dive detail
      // providers -- re-running the expensive Buhlmann analysis and, while the
      // dive_profiles rows are mid-rewrite, transiently blanking the deco /
      // tissue / O2 cards. The aggregate detail-change stream must debounce a
      // burst so listeners refresh ONCE on the settled DB state.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1, maxDepth: 20.0),
      );

      final db = DatabaseService.instance.database;
      final repo = DiveRepository();

      var ticks = 0;
      final sub = repo.watchDiveDetailChanges().listen((_) => ticks++);
      addTearDown(sub.cancel);

      // Fire a rapid burst, like a lagging peer's changesets applied
      // back-to-back. Each write is its own transaction -> its own commit.
      for (var i = 0; i < 10; i++) {
        await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
          DivesCompanion(maxDepth: Value(21.0 + i)),
        );
      }

      // Let the trailing debounce window elapse.
      await Future<void>.delayed(
        DiveRepository.changeTickDebounce + const Duration(milliseconds: 150),
      );

      expect(
        ticks,
        1,
        reason:
            'a burst of N writes must coalesce into ONE detail-change tick so '
            'the per-dive providers recompute once on the settled state, not '
            'once per intermediate sync write (stutter + card flicker)',
      );
    },
  );

  test(
    'watchDivesChanges coalesces a burst of writes into a single tick',
    () async {
      // The dives-table tick fans out to the list, stats, dashboard, sites,
      // trips and buddy providers app-wide. The same per-changeset sync burst
      // must coalesce here too, so those cross-feature providers re-query once
      // on the settled state instead of once per intermediate commit.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1, maxDepth: 20.0),
      );

      final db = DatabaseService.instance.database;
      final repo = DiveRepository();

      var ticks = 0;
      final sub = repo.watchDivesChanges().listen((_) => ticks++);
      addTearDown(sub.cancel);

      for (var i = 0; i < 10; i++) {
        await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
          DivesCompanion(maxDepth: Value(21.0 + i)),
        );
      }

      await Future<void>.delayed(
        DiveRepository.changeTickDebounce + const Duration(milliseconds: 150),
      );

      expect(
        ticks,
        1,
        reason:
            'a burst of N dives-table writes must coalesce into ONE tick so the '
            'list/stats/dashboard providers re-query once, not once per sync '
            'commit',
      );
    },
  );
}
