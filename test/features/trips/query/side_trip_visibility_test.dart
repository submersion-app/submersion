import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_history_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../helpers/shared_items_fixture.dart';
import '../../../helpers/test_database.dart';

/// A parent the profile cannot see is no parent for it (issue #3933): the
/// comparisons across trips read the same trips the Trips list shows. Profile
/// `a` owns larger trip P and its side trip C; profile `b` logs dives on C.
void main() {
  late AppDatabase db;
  const day = 86400000;

  Future<void> trip(
    String id, {
    String owner = 'a',
    String? parent,
    bool shared = false,
    int endDay = 10,
  }) => db.customStatement(
    'INSERT INTO trips (id, name, location, start_date, end_date, diver_id, '
    'is_shared, parent_trip_id, created_at, updated_at) '
    'VALUES (?, ?, ?, 0, ?, ?, ?, ?, 0, 0)',
    [id, 'Trip $id', 'At $id', endDay * day, owner, shared ? 1 : 0, parent],
  );

  Future<void> dive(
    String id,
    String tripId, {
    String diver = 'b',
    int onDay = 1,
  }) => db.customStatement(
    'INSERT INTO dives (id, diver_id, dive_date_time, trip_id, created_at, '
    'updated_at) VALUES (?, ?, ?, ?, 0, 0)',
    [id, diver, onDay * day + 3600000, tripId],
  );

  Future<void> shareWith(String tripId, String diverId) => db.customStatement(
    'INSERT INTO trip_shares (id, trip_id, diver_id, created_at) '
    'VALUES (?, ?, ?, 0)',
    ['$tripId-$diverId', tripId, diverId],
  );

  Future<void> shareWithEveryone(String tripId) => db.customStatement(
    'UPDATE trips SET is_shared = 1 WHERE id = ?',
    [tripId],
  );

  Future<void> hide(String tripId, String diverId) =>
      ProfileHidesRepository().hide(SharedItemKind.trip, tripId, diverId);

  Future<List<(String, int)>> ranking(
    String? diverId, {
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    final items = await InsightsRepository().getDivesPerTrip(
      diverId: diverId,
      filter: filter,
    );
    return [for (final r in items) (r.id, r.count)];
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['a', 'b']);
    await trip('P');
    await trip('C', parent: 'P');
    await shareWith('C', 'b');
    await dive('b1', 'C');
  });
  tearDown(tearDownTestDatabase);

  group('dives per trip', () {
    test('a side trip of a private parent ranks as itself', () async {
      final items = await InsightsRepository().getDivesPerTrip(diverId: 'b');
      expect(items.map((r) => (r.id, r.name, r.subtitle, r.count)), [
        ('C', 'Trip C', 'At C', 1),
      ]);
    });

    test('it agrees with the Trips list on the same fixture', () async {
      final trips = await TripRepository().getAllTripsWithStats(diverId: 'b');
      expect(trips.map((t) => (t.trip.id, t.diveCount)), [('C', 1)]);
      expect(await ranking('b'), [('C', 1)]);
    });

    test('a parent the profile hid is no parent either', () async {
      await shareWithEveryone('P');
      await hide('P', 'b');
      expect(await ranking('b'), [('C', 1)]);
    });

    test('a parent shared with the profile still takes the dives', () async {
      await shareWith('P', 'b');
      await dive('b2', 'P');
      expect(await ranking('b'), [('P', 2)]);
    });

    test('a parent shared with everyone still takes the dives', () async {
      await shareWithEveryone('P');
      expect(await ranking('b'), [('P', 1)]);
    });

    test('its owner still reads the larger trip', () async {
      await dive('a1', 'C', diver: 'a');
      await dive('a2', 'P', diver: 'a');
      expect(await ranking('a'), [('P', 2)]);
    });

    test('two side trips of a private parent rank apart', () async {
      await trip('C2', parent: 'P');
      await shareWith('C2', 'b');
      await dive('b2', 'C2');
      await dive('b3', 'C2');
      expect(await ranking('b'), [('C2', 2), ('C', 1)]);
    });

    test('a trip the profile cannot see is not ranked at all', () async {
      await trip('Hidden', shared: true);
      await dive('b2', 'Hidden');
      await hide('Hidden', 'b');
      await trip('Unshared');
      await dive('b3', 'Unshared');
      expect(await ranking('b'), [('C', 1)]);
    });

    test(
      'a visible parent keeps a hidden side trip, as the list does',
      () async {
        await shareWith('P', 'b');
        await hide('C', 'b');
        final trips = await TripRepository().getAllTripsWithStats(diverId: 'b');
        expect(trips.map((t) => (t.trip.id, t.diveCount)), [('P', 1)]);
        expect(await ranking('b'), [('P', 1)]);
      },
    );

    test('a user filter binds after the visibility variables', () async {
      await dive('b2', 'C', onDay: 5);
      expect(
        await ranking(
          'b',
          filter: DiveFilterState(
            startDate: DateTime.fromMillisecondsSinceEpoch(4 * day),
          ),
        ),
        [('C', 1)],
      );
    });

    test('no profile applies no visibility, as before', () async {
      expect(await ranking(null), [('P', 1)]);
    });
  });

  group('dives per dive day', () {
    Future<List<double>> rates(String? diverId) =>
        TripHistoryRepository(db: db).divesPerDiveDay(
          diverId: diverId,
          before: DateTime.fromMillisecondsSinceEpoch(20 * day),
        );

    setUp(() async {
      await dive('b2', 'C');
      await trip('C2', parent: 'P', endDay: 8);
      await shareWith('C2', 'b');
      await dive('b3', 'C2', onDay: 2);
    });

    test('samples each side trip of a private parent on its own', () async {
      // Rolled into P they would read 3 dives over 2 days.
      expect(await rates('b'), [2, 1]);
    });

    test('a parent the profile hid is no parent either', () async {
      await shareWithEveryone('P');
      await hide('P', 'b');
      expect(await rates('b'), [2, 1]);
    });

    test('a visible parent still samples its side trips together', () async {
      await shareWith('P', 'b');
      expect(await rates('b'), [1.5]);
    });

    test('a trip the profile cannot see is not sampled', () async {
      await hide('C2', 'b');
      expect(await rates('b'), [2]);
    });

    test('no profile applies no visibility, as before', () async {
      expect(await rates(null), [1.5]);
    });
  });

  group('insights refresh', () {
    Future<bool> fires(Future<void> Function() write) async {
      var fired = false;
      final sub = InsightsRepository().watchInsightsChanges().listen(
        (_) => fired = true,
      );
      addTearDown(sub.cancel);
      await write();
      for (var i = 0; i < 150 && !fired; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return fired;
    }

    test('on a hide, which writes no trip row', () async {
      await shareWithEveryone('P');
      expect(await fires(() => hide('P', 'b')), isTrue);
    });

    test('on a share, which writes no trip row', () async {
      expect(
        await fires(
          () => db
              .into(db.tripShares)
              .insert(
                TripSharesCompanion.insert(
                  id: 'P-b',
                  tripId: 'P',
                  diverId: 'b',
                  createdAt: 0,
                ),
              ),
        ),
        isTrue,
      );
    });
  });
}
