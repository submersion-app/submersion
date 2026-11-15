import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/trips/data/repositories/trip_undived_plan_queries.dart';

import '../../../../helpers/test_database.dart';

/// The trip day picker draws a dive that has not happened as a dashed
/// outline. Which of a trip's planned dives that is comes from the app's one
/// undived rule (issue #3924): a plan with no logged dive on its outing.
void main() {
  late AppDatabase db;
  late TripUndivedPlanQueries queries;

  Future<void> trip(String id, {String? parent}) => db.customStatement(
    'INSERT INTO trips (id, name, start_date, end_date, parent_trip_id, '
    'created_at, updated_at) VALUES (?, ?, 0, 0, ?, 0, 0)',
    [id, id, parent],
  );

  Future<void> dive(
    String id,
    String tripId, {
    bool planned = false,
    bool draft = false,
    String? outing,
  }) => db.customStatement(
    'INSERT INTO dives (id, dive_date_time, trip_id, is_planned, is_draft, '
    'outing_id, created_at, updated_at) VALUES (?, 0, ?, ?, ?, ?, 0, 0)',
    [id, tripId, planned ? 1 : 0, draft ? 1 : 0, outing],
  );

  setUp(() async {
    db = await setUpTestDatabase();
    queries = TripUndivedPlanQueries();
    await trip('t1');
    await trip('t1s', parent: 't1');
    await trip('t2');
    await dive('logged', 't1');
    await dive('plan', 't1', planned: true);
    await dive('draft', 't1', draft: true);
    // Mirrored from a buddy's logged dive: planned, but it happened.
    await dive('mirror', 't1', planned: true, outing: 'o1');
    await dive('source', 't2', outing: 'o1');
    // On an outing nobody has logged a dive for.
    await dive('lonely', 't1', planned: true, outing: 'o2');
    await dive('sidePlan', 't1s', planned: true);
  });
  tearDown(tearDownTestDatabase);

  test('names the plans nobody has dived, side trips included', () async {
    expect(await queries.undivedPlanIds('t1'), {'plan', 'lonely', 'sidePlan'});
  });

  test('a trip with no plans has none', () async {
    expect(await queries.undivedPlanIds('t2'), isEmpty);
  });

  test('a read that fails throws: it does not answer with no plans', () async {
    await db.customStatement('ALTER TABLE dives RENAME TO dives_elsewhere');

    // An empty set would say every plan was dived. The failure reaches the
    // picker instead, which goes on not knowing and leaves plans undrawn.
    await expectLater(queries.undivedPlanIds('t1'), throwsA(anything));
  });
}
