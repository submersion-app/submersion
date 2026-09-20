import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// The paginated dive list sorts by site name in SQL. SQLite's default
/// BINARY collation put every capitalised site before every lowercase one
/// (issue #2038).
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiveAt(String id, String siteName, int dateTimeMs) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value('site-$id'),
            name: Value(siteName),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(dateTimeMs),
            siteId: Value('site-$id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  const siteAscending = SortState(
    field: DiveSortField.site,
    direction: SortDirection.ascending,
  );

  test(
    'site sort ignores case in the paged summaries and ordered ids',
    () async {
      await insertDiveAt('zebra', 'Zebra Reef', 1000);
      await insertDiveAt('lower', 'plage', 2000);
      await insertDiveAt('anchor', 'anchor', 3000);
      await insertDiveAt('upper', 'Plage', 4000);

      final summaries = await repository.getDiveSummaries(
        sort: siteAscending,
        limit: 1000,
      );
      final ids = await repository.getOrderedDiveIds(sort: siteAscending);

      // "Plage" and "plage" tie under NOCASE, so the existing tiebreaker
      // (newest first) orders them.
      const expected = ['anchor', 'upper', 'lower', 'zebra'];
      expect(summaries.map((s) => s.id).toList(), expected);
      expect(ids, expected);
    },
  );
}
