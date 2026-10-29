import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/trips/data/repositories/trip_history_repository.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/query/trip_filter_query.dart';

import '../../../helpers/test_database.dart';

/// Side trips in rankings, the dives-per-day history, the query language
/// and the dive list's trip filter (issue #3658). P has 2 dives of its own
/// on one day and S, part of P, has 3 on another.
void main() {
  late AppDatabase db;
  const day = 86400000;

  Future<void> trip(String id, {String? parent}) => db.customStatement(
    'INSERT INTO trips (id, name, start_date, end_date, parent_trip_id, '
    'created_at, updated_at) VALUES (?, ?, 0, ?, ?, 0, 0)',
    [id, id, 10 * day, parent],
  );

  Future<void> dive(String id, String tripId, int onDay) => db.customStatement(
    'INSERT INTO dives (id, dive_date_time, trip_id, created_at, updated_at) '
    'VALUES (?, ?, ?, 0, 0)',
    [id, onDay * day + 3600000, tripId],
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await trip('P');
    await trip('S', parent: 'P');
    await dive('p1', 'P', 1);
    await dive('p2', 'P', 1);
    await dive('s1', 'S', 2);
    await dive('s2', 'S', 2);
    await dive('s3', 'S', 2);
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> tripIds(QueryNode node) =>
      QueryIdSetRunner(db).ids(compileTripFilter(TripFilterState(query: node)));

  test('top trips rank the larger trip with all its dives', () async {
    final ranking = await InsightsRepository().getDivesPerTrip();
    expect(ranking.map((r) => (r.id, r.count)), [('P', 5)]);
  });

  test('the dives-per-day history samples only the larger trip', () async {
    final rates = await TripHistoryRepository(
      db: db,
    ).divesPerDiveDay(before: DateTime.fromMillisecondsSinceEpoch(20 * day));
    expect(rates, [2.5]);
  });

  test('the query diveCount counts side-trip dives', () async {
    expect(
      await tripIds(
        ConditionNode(
          FieldPath(['diveCount']),
          QueryOp.gt,
          const NumberValue(4, null),
        ),
      ),
      {'P'},
    );
  });

  test('partOf finds the side trips of a trip', () async {
    expect(
      await tripIds(
        ConditionNode(
          FieldPath(['partOf']),
          QueryOp.eq,
          const RefValue('P', 'P'),
        ),
      ),
      {'S'},
    );
  });

  test("the dive list's trip filter takes in side-trip dives", () async {
    Future<Set<String>> dives(String tripId) => QueryIdSetRunner(
      db,
    ).ids(compileDiveFilter(DiveFilterState(tripId: tripId)));
    expect(await dives('P'), {'p1', 'p2', 's1', 's2', 's3'});
    expect(await dives('S'), {'s1', 's2', 's3'});
  });

  test("a trip filter on dives takes in its side trips' dives", () async {
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('drysuit', 'Drysuit', 'drysuit', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) "
      "VALUES ('s1', 'drysuit')",
    );
    expect(
      await QueryIdSetRunner(
        db,
      ).ids(compileTripFilter(const TripFilterState(equipmentId: 'drysuit'))),
      {'P', 'S'},
    );
  });
}
