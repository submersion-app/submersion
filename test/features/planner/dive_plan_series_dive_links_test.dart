import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../helpers/test_database.dart';

/// `dive_plan_series.followed_dive_id` references `dives` with no ON DELETE
/// action (issue #3565). Under `PRAGMA foreign_keys = ON` a series following
/// a dive would fail that dive's delete with SqliteException(787), so the
/// delete clears the link, stamps the series and marks it pending.
void main() {
  late DiveRepository repository;
  late AppDatabase db;
  const stale = 1000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDive(String id) => repository.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1)),
  );

  Future<void> seedSeries(String id, {required String followedDiveId}) => db
      .into(db.divePlanSeries)
      .insert(
        DivePlanSeriesCompanion.insert(
          id: id,
          name: id,
          followedDiveId: Value(followedDiveId),
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  Future<QueryRow> seriesRow(String id) => db
      .customSelect(
        'SELECT followed_dive_id, updated_at FROM dive_plan_series '
        'WHERE id = ?',
        variables: [Variable<String>(id)],
      )
      .getSingle();

  Future<int> pendingCountFor(String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = '
                "'divePlanSeries' AND record_id = ? "
                "AND sync_status = 'pending'",
                variables: [Variable<String>(recordId)],
              )
              .getSingle())
          .read<int>('n');

  Future<void> expectCleared(String id) async {
    final row = await seriesRow(id);
    expect(row.readNullable<String>('followed_dive_id'), isNull);
    expect(row.read<int>('updated_at'), greaterThan(stale));
    expect(await pendingCountFor(id), 1);
  }

  Future<void> expectUntouched(String id, {required String diveId}) async {
    final row = await seriesRow(id);
    expect(row.readNullable<String>('followed_dive_id'), diveId);
    expect(row.read<int>('updated_at'), stale);
    expect(await pendingCountFor(id), 0);
  }

  test('deleteDive frees a series that follows the dive and leaves series '
      'following other dives alone', () async {
    await seedDive('dive-a');
    await seedDive('dive-b');
    await seedSeries('series-a', followedDiveId: 'dive-a');
    await seedSeries('series-b', followedDiveId: 'dive-b');
    await db.customStatement('DELETE FROM sync_records');

    await repository.deleteDive('dive-a');

    await expectCleared('series-a');
    await expectUntouched('series-b', diveId: 'dive-b');
  });

  test(
    'bulkDeleteDives frees every series following any of the dives',
    () async {
      await seedDive('dive-a');
      await seedDive('dive-b');
      await seedDive('dive-c');
      await seedSeries('series-a', followedDiveId: 'dive-a');
      await seedSeries('series-b', followedDiveId: 'dive-b');
      await seedSeries('series-c', followedDiveId: 'dive-c');
      await db.customStatement('DELETE FROM sync_records');

      await repository.bulkDeleteDives(['dive-a', 'dive-b']);

      await expectCleared('series-a');
      await expectCleared('series-b');
      await expectUntouched('series-c', diveId: 'dive-c');
    },
  );
}
