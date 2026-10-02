import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// A trip one profile hides leaves that profile's lists only (issue #2594).
void main() {
  late AppDatabase db;
  late TripRepository trips;

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripRepository();
    await seedDivers(db, ['a', 'b', 'c']);
    await seedTrip(db, 'shared', owner: 'a', shared: true, name: 'Bonaire');
    await ProfileHidesRepository().hide(SharedItemKind.trip, 'shared', 'b');
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> visibleTo(String diverId) async => [
    for (final t in await trips.getAllTrips(diverId: diverId)) t.id,
  ];

  test('getAllTrips hides it from b, not from a or c', () async {
    expect(await visibleTo('b'), isEmpty);
    expect(await visibleTo('a'), ['shared']);
    expect(await visibleTo('c'), ['shared']);
  });

  test(
    'getAllTripsWithStats, search and findTripForDate hide it from b',
    () async {
      expect(await trips.getAllTripsWithStats(diverId: 'b'), isEmpty);
      expect(await trips.getAllTripsWithStats(diverId: 'c'), hasLength(1));
      expect(await trips.searchTrips('bon', diverId: 'b'), isEmpty);
      expect(await trips.searchTrips('bon', diverId: 'c'), hasLength(1));
      final date = DateTime.fromMillisecondsSinceEpoch(kSharedTs);
      expect(await trips.findTripForDate(date, diverId: 'b'), isNull);
      expect((await trips.findTripForDate(date, diverId: 'c'))?.id, 'shared');
    },
  );

  test('a lookup by id still finds it', () async {
    expect((await trips.getTripById('shared'))?.name, 'Bonaire');
  });

  test('watchTripsChanges ticks on a hide', () async {
    await seedTrip(db, 'other', owner: 'a', shared: true);
    final tick = trips.watchTripsChanges().first.timeout(
      const Duration(seconds: 5),
    );
    await ProfileHidesRepository().hide(SharedItemKind.trip, 'other', 'b');
    await expectLater(tick, completes);
  });
}
