import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

/// The larger trip a side trip is part of (issue #3658) is stored, read back
/// by every mapper, and cleared on demand.
void main() {
  late TripRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = TripRepository();
  });
  tearDown(tearDownTestDatabase);

  Trip trip(String name, {String? parentTripId}) {
    final now = DateTime(2026, 3, 1);
    return Trip(
      id: '',
      name: name,
      startDate: DateTime(2026, 3, 2),
      endDate: DateTime(2026, 3, 16),
      parentTripId: parentTripId,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('Trip.copyWith keeps, sets and clears the parent', () {
    final side = trip('Raja Ampat', parentTripId: 'p1');
    expect(side.copyWith(name: 'x').parentTripId, 'p1');
    expect(side.copyWith(parentTripId: 'p2').parentTripId, 'p2');
    expect(side.copyWith(parentTripId: null).parentTripId, isNull);
    expect(side, isNot(side.copyWith(parentTripId: 'p2')));
  });

  test('createTrip stores the parent and getTripById reads it', () async {
    final parent = await repository.createTrip(trip('Indonesia'));
    final side = await repository.createTrip(
      trip('Raja Ampat', parentTripId: parent.id),
    );
    final read = await repository.getTripById(side.id);
    expect(read!.parentTripId, parent.id);
  });

  test('updateTrip clears the parent', () async {
    final parent = await repository.createTrip(trip('Indonesia'));
    final side = await repository.createTrip(
      trip('Raja Ampat', parentTripId: parent.id),
    );
    await repository.updateTrip(side.copyWith(parentTripId: null));
    expect((await repository.getTripById(side.id))!.parentTripId, isNull);
  });

  test('the stats list and search map the parent', () async {
    final parent = await repository.createTrip(trip('Indonesia'));
    final side = await repository.createTrip(
      trip('Raja Ampat', parentTripId: parent.id),
    );
    final all = await repository.getAllTripsWithStats();
    expect(
      all.singleWhere((t) => t.trip.id == side.id).trip.parentTripId,
      parent.id,
    );
    final found = await repository.searchTrips('Raja');
    expect(found.single.parentTripId, parent.id);
  });
}
