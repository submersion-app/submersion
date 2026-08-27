import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = StatisticsRepository();

    // Foreign keys are enforced (beforeOpen turns them on), so the parent
    // diver and site rows must exist before any dive references them.
    for (final diverId in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: diverId,
              name: diverId,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    for (final siteId in ['s1', 's2']) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: siteId,
              name: siteId,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<void> insertDive({
    required String id,
    required String siteId,
    required String diverId,
    String? entry,
    String? exit,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: 0,
            createdAt: 0,
            updatedAt: 0,
            diverId: Value(diverId),
            siteId: Value(siteId),
            entryMethod: Value(entry),
            exitMethod: Value(exit),
          ),
        );
  }

  test('returns the modal entry/exit pair for the site', () async {
    await insertDive(
      id: 'd1',
      siteId: 's1',
      diverId: 'me',
      entry: 'giantStride',
      exit: 'ladder',
    );
    await insertDive(
      id: 'd2',
      siteId: 's1',
      diverId: 'me',
      entry: 'giantStride',
      exit: 'ladder',
    );
    await insertDive(
      id: 'd3',
      siteId: 's1',
      diverId: 'me',
      entry: 'shore',
      exit: 'shore',
    );

    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 's1',
      diverId: 'me',
    );

    expect(pairs.first.entryMethod, 'giantStride');
    expect(pairs.first.exitMethod, 'ladder');
    expect(pairs.first.count, 2);
  });

  test('groups on the pair rather than on each column independently', () async {
    // Regression guard for the exit-mirroring bias: the dive form defaults
    // exit to mirror entry, so most rows carry exit == entry for values the
    // diver never set. Grouping jointly keeps the two pairings distinct
    // instead of collapsing them into one inflated exit mode.
    await insertDive(
      id: 'd1',
      siteId: 's1',
      diverId: 'me',
      entry: 'boat',
      exit: 'boat',
    );
    await insertDive(
      id: 'd2',
      siteId: 's1',
      diverId: 'me',
      entry: 'boat',
      exit: 'boat',
    );
    await insertDive(
      id: 'd3',
      siteId: 's1',
      diverId: 'me',
      entry: 'boat',
      exit: 'ladder',
    );

    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 's1',
      diverId: 'me',
    );

    expect(pairs.length, 2);
    expect(pairs.first.exitMethod, 'boat');
    expect(pairs.first.count, 2);
    expect(pairs[1].exitMethod, 'ladder');
    expect(pairs[1].count, 1);
  });

  test('excludes dives with no entry method', () async {
    await insertDive(id: 'd1', siteId: 's1', diverId: 'me', entry: null);
    await insertDive(id: 'd2', siteId: 's1', diverId: 'me', entry: '');

    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 's1',
      diverId: 'me',
    );

    expect(pairs, isEmpty);
  });

  test('carries a null exit method through as null', () async {
    await insertDive(
      id: 'd1',
      siteId: 's1',
      diverId: 'me',
      entry: 'shore',
      exit: null,
    );

    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 's1',
      diverId: 'me',
    );

    expect(pairs.first.entryMethod, 'shore');
    expect(pairs.first.exitMethod, isNull);
  });

  test('ignores dives at other sites and other divers', () async {
    await insertDive(
      id: 'd1',
      siteId: 's1',
      diverId: 'me',
      entry: 'shore',
      exit: 'shore',
    );
    await insertDive(
      id: 'd2',
      siteId: 's2',
      diverId: 'me',
      entry: 'boat',
      exit: 'boat',
    );
    await insertDive(
      id: 'd3',
      siteId: 's1',
      diverId: 'other',
      entry: 'boat',
      exit: 'boat',
    );

    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 's1',
      diverId: 'me',
    );

    expect(pairs.length, 1);
    expect(pairs.first.entryMethod, 'shore');
  });

  test('returns an empty list when the site has no dives', () async {
    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 'nobody-dived-here',
      diverId: 'me',
    );

    expect(pairs, isEmpty);
  });
}
