import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

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
}
