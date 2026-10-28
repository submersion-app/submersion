import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/trips/data/repositories/side_trip_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

/// A larger trip's per-trip figures include its side trips' dives, and the
/// side trips can be looked up both ways (issue #3658).
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late SideTripRepository sideTrips;

  Future<void> trip(String id, {String? parent, String? owner}) =>
      db.customStatement(
        'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
        'parent_trip_id, created_at, updated_at) '
        'VALUES (?, ?, ?, 0, 0, ?, 0, 0)',
        [id, owner, id, parent],
      );

  Future<void> dive(String id, String tripId, double depth) =>
      db.customStatement(
        'INSERT INTO dives (id, dive_date_time, trip_id, max_depth, runtime, '
        'created_at, updated_at) VALUES (?, 0, ?, ?, 600, 0, 0)',
        [id, tripId, depth],
      );

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripRepository();
    sideTrips = SideTripRepository();
    await trip('P');
    await trip('S', parent: 'P');
    await dive('p1', 'P', 20);
    await dive('p2', 'P', 22);
    await dive('s1', 'S', 31);
    await dive('s2', 'S', 25);
    await dive('s3', 'S', 18);
  });
  tearDown(tearDownTestDatabase);

  test('the larger trip lists its side trip dives too', () async {
    expect(await trips.getDiveIdsForTrip('P'), hasLength(5));
    expect(await trips.getDiveIdsForTrip('S'), hasLength(3));
    expect(await trips.getDiveCountForTrip('P'), 5);
  });

  test('the larger trip stats span its side trips', () async {
    final stats = await trips.getTripWithStats('P');
    expect(stats.diveCount, 5);
    expect(stats.maxDepth, 31);
    expect(stats.totalRuntime, 3000);
    expect((await trips.getTripWithStats('S')).diveCount, 3);
  });

  test('the trip list counts each trip inclusively', () async {
    final all = {
      for (final t in await trips.getAllTripsWithStats()) t.trip.id: t,
    };
    expect(all['P']!.diveCount, 5);
    expect(all['S']!.diveCount, 3);
  });

  test('an invalid link counts nothing extra', () async {
    // P made a side trip itself: S's link to P is now two deep.
    await trip('Q');
    await db.customStatement(
      "UPDATE trips SET parent_trip_id = 'Q' "
      "WHERE id = 'P'",
    );
    expect(await trips.getDiveCountForTrip('P'), 2);
    expect(await trips.getDiveCountForTrip('Q'), 2);
  });

  test('side trips and the parent are looked up both ways', () async {
    expect((await sideTrips.getSideTrips('P')).map((t) => t.id), ['S']);
    expect((await sideTrips.getParentTrip('S'))!.id, 'P');
    expect(await sideTrips.getParentTrip('P'), isNull);
  });

  test('a parent the profile cannot see is no parent', () async {
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', 0, 0), ('other', 'Other', 0, 0)",
    );
    await trip('Hidden', owner: 'other');
    await trip('T', parent: 'Hidden', owner: 'me');
    expect(await sideTrips.getParentTrip('T', diverId: 'me'), isNull);
    expect((await sideTrips.getParentTrip('T'))!.id, 'Hidden');
  });

  test("a larger trip's scan leaves its side trips' dives alone", () async {
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', 0, 0)",
    );
    await db.customStatement("UPDATE dives SET diver_id = 'me'");
    await trip('Q');
    await dive('q1', 'Q', 12);
    await db.customStatement("UPDATE dives SET diver_id = 'me'");
    final candidates = await trips.findCandidateDivesForTrip(
      tripId: 'P',
      startDate: DateTime.fromMillisecondsSinceEpoch(0),
      endDate: DateTime(2100),
      diverId: 'me',
    );
    expect(candidates.map((c) => c.dive.id), ['q1']);
  });

  test('a failed read is rethrown, not swallowed', () async {
    await tearDownTestDatabase();
    await expectLater(sideTrips.getSideTrips('P'), throwsA(anything));
    await expectLater(sideTrips.hasSideTrips('P'), throwsA(anything));
    await expectLater(sideTrips.getParentTrip('S'), throwsA(anything));
    await expectLater(sideTrips.getVisibleTrip('S'), throwsA(anything));
    db = await setUpTestDatabase();
  });
}
