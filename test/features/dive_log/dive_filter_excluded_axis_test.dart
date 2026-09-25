import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../helpers/test_database.dart';

/// The excluded-dives axis (#526) once had three implementations that had to
/// agree. Since #2365 there is one: the filter lowers to a query tree and
/// every path compiles it. This pins the rule that tree encodes, against the
/// database, on the two id paths the entity views and Statistics use.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    final now = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    Future<void> dive(
      String id, {
      bool excluded = false,
      bool gasExcluded = false,
      bool favorite = false,
    }) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: now,
            excludedFromStats: Value(excluded),
            excludedFromGasStats: Value(gasExcluded),
            isFavorite: Value(favorite),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dive('included');
    await dive('excluded', excluded: true);
    await dive('gas-excluded', gasExcluded: true);
    await dive('both', excluded: true, favorite: true);
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> statisticsIds(DiveFilterState filter) async {
    final f = buildFilteredDiveIdSubquery(filter);
    final rows = await db
        .customSelect(
          f.subquery.isEmpty ? 'SELECT id FROM dives' : f.subquery,
          variables: f.params.map((p) => Variable(p)).toList(),
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('a null axis is inactive and filters nothing', () async {
    const filter = DiveFilterState();
    expect(filter.hasActiveFilters, isFalse);
    expect(await repo.getDiveIdsMatching(filter), hasLength(4));
    expect(
      buildFilteredDiveIdSubquery(filter).subquery,
      isEmpty,
      reason:
          'an inactive filter must stay a no-op; the exclusion is '
          'enforced by DiveStatsScope alongside this subquery, not inside it',
    );
  });

  test('the axis keeps only excluded dives when true', () async {
    const filter = DiveFilterState(excludedFromStatsOnly: true);
    expect(filter.hasActiveFilters, isTrue);
    expect(
      await repo.getDiveIdsMatching(filter),
      {'excluded', 'both'},
      reason:
          'the axis tracks the master flag only; a gas-excluded dive is '
          'not "excluded from statistics"',
    );
    expect(await statisticsIds(filter), {'excluded', 'both'});
  });

  test('the SQL encodes the master flag and never the gas flag', () {
    const filter = DiveFilterState(excludedFromStatsOnly: true);
    final sql = buildFilteredDiveIdSubquery(filter);
    expect(sql.subquery, contains('excluded_from_stats = ?'));
    expect(sql.params, [1]);
    expect(
      sql.subquery,
      isNot(contains('excluded_from_gas_stats')),
      reason: 'the axis does not consider the gas flag',
    );
  });

  test('copyWith can set and clear the axis', () {
    const active = DiveFilterState(excludedFromStatsOnly: true);
    expect(
      active.copyWith(clearExcludedFromStatsOnly: true).excludedFromStatsOnly,
      isNull,
    );
    expect(
      const DiveFilterState()
          .copyWith(excludedFromStatsOnly: true)
          .excludedFromStatsOnly,
      isTrue,
    );
  });

  test(
    'the axis composes with other axes rather than replacing them',
    () async {
      const filter = DiveFilterState(
        excludedFromStatsOnly: true,
        favoritesOnly: true,
      );
      expect(await repo.getDiveIdsMatching(filter), {'both'});
      expect(await statisticsIds(filter), {'both'});
    },
  );
}
