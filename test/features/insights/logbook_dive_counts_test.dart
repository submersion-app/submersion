import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/logbook_dive_counts.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_database.dart';

void main() {
  group('LogbookDiveCounts', () {
    test('an empty logbook has nothing excluded', () {
      const counts = LogbookDiveCounts(logged: 0, counted: 0);
      expect(counts.allExcluded, isFalse);
    });

    test('logged dives with none counted are all excluded', () {
      const counts = LogbookDiveCounts(logged: 3, counted: 0);
      expect(counts.allExcluded, isTrue);
    });

    test('a single counted dive means not all are excluded', () {
      const counts = LogbookDiveCounts(logged: 3, counted: 1);
      expect(counts.allExcluded, isFalse);
    });
  });

  group('countLogbookDives', () {
    late AppDatabase db;
    late InsightsRepository repo;

    Future<void> insert(
      String id, {
      bool excluded = false,
      bool planned = false,
      String? diverId,
    }) async {
      final at = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diveDateTime: Value(at),
              excludedFromStats: Value(excluded),
              isPlanned: Value(planned),
              diverId: Value(diverId),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
    }

    Future<void> insertDiver(String id) async {
      final at = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(id),
              name: Value(id),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
    }

    setUp(() async {
      db = await setUpTestDatabase();
      repo = InsightsRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    test('an empty logbook counts zero of both', () async {
      final counts = await repo.countLogbookDives();
      expect(counts.logged, 0);
      expect(counts.counted, 0);
    });

    test('an excluded dive is logged but not counted', () async {
      await insert('kept');
      await insert('excluded', excluded: true);

      final counts = await repo.countLogbookDives();

      expect(counts.logged, 2);
      expect(counts.counted, 1);
    });

    test('a planned dive is neither logged nor counted', () async {
      await insert('planned', planned: true);

      final counts = await repo.countLogbookDives();

      expect(
        counts.logged,
        0,
        reason:
            'a plan is a dive that has not happened, so a logbook holding '
            'only plans still needs the first-dive prompt',
      );
      expect(counts.counted, 0);
    });

    test('a planned dive that is also excluded is not logged', () async {
      await insert('kept');
      await insert('planned', planned: true, excluded: true);

      final counts = await repo.countLogbookDives();

      expect(counts.logged, 1);
      expect(counts.counted, 1);
      expect(
        counts.allExcluded,
        isFalse,
        reason:
            'the one real dive counts, however many excluded plans sit '
            'beside it',
      );
    });

    test('counts every dive excluded as all excluded', () async {
      await insert('a', excluded: true);
      await insert('b', excluded: true);

      final counts = await repo.countLogbookDives();

      expect(counts.logged, 2);
      expect(counts.counted, 0);
      expect(counts.allExcluded, isTrue);
    });

    test('counts only the given diver', () async {
      await insertDiver('me');
      await insertDiver('other');
      await insert('mine', diverId: 'me', excluded: true);
      await insert('theirs', diverId: 'other');

      final counts = await repo.countLogbookDives(diverId: 'me');

      expect(counts.logged, 1);
      expect(counts.counted, 0);
    });

    test('counted agrees with the unfiltered statistics total', () async {
      await insert('kept');
      await insert('also-kept');
      await insert('excluded', excluded: true);
      await insert('planned', planned: true);

      final counts = await repo.countLogbookDives();
      final stats = await DiveRepository().getStatistics();

      expect(
        counts.counted,
        stats.totalDives,
        reason:
            'a zero from the statistics is only explained by these counts '
            'while both draw the same line around which dives count',
      );
    });
  });

  group('logbookDiveCountsProvider', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    test(
      'follows a dive being un-excluded with no notifier involved',
      () async {
        final repository = DiveRepository();
        await repository.createDive(
          createTestDiveWithBottomTime(
            id: 'd1',
          ).copyWith(excludedFromStats: true),
        );

        final container = ProviderContainer(
          overrides: [
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            gasModelProvider.overrideWith((ref) => GasModel.real),
          ],
        );
        addTearDown(container.dispose);
        final onScreen = container.listen(logbookDiveCountsProvider, (_, _) {});
        addTearDown(onScreen.close);

        final before = await container.read(logbookDiveCountsProvider.future);
        expect(before.allExcluded, isTrue);

        final db = DatabaseService.instance.database;
        await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
          const DivesCompanion(excludedFromStats: Value(false)),
        );

        // The tick is debounced, so the refresh is never immediate.
        var after = before;
        for (var i = 0; i < 100 && after.allExcluded; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          after = await container.read(logbookDiveCountsProvider.future);
        }
        expect(after.counted, 1);
        expect(after.allExcluded, isFalse);
      },
    );
  });
}
