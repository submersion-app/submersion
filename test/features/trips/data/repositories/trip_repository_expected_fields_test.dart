import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

/// Both trip mappers (the Drift row and the customSelect map) carry the
/// scrubber margin overrides, and an update can clear them.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('round-trips through both mappers and clears on update', () async {
    final repo = TripRepository();
    final created = await repo.createTrip(
      Trip(
        id: '',
        name: 'Red Sea',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 8),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        expectedDives: 12,
        expectedRuntimeMinutes: 70,
      ),
    );
    final byId = await repo.getTripById(created.id);
    expect(byId!.expectedDives, 12);
    expect(byId.expectedRuntimeMinutes, 70);
    final withStats = await repo.getAllTripsWithStats();
    expect(withStats.single.trip.expectedDives, 12);
    expect(withStats.single.trip.expectedRuntimeMinutes, 70);

    await repo.updateTrip(
      byId.copyWith(expectedDives: null, expectedRuntimeMinutes: null),
    );
    final cleared = await repo.getTripById(created.id);
    expect(cleared!.expectedDives, isNull);
    expect(cleared.expectedRuntimeMinutes, isNull);
  });

  test('the fill forecast fields round-trip through both mappers', () async {
    final repo = TripRepository();
    final created = await repo.createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        diversSharingCylinders: 3,
        divesPerDayTarget: 2,
      ),
    );
    final byId = await repo.getTripById(created.id);
    expect(byId!.diversSharingCylinders, 3);
    expect(byId.divesPerDayTarget, 2);
    final withStats = await repo.getAllTripsWithStats();
    expect(withStats.single.trip.diversSharingCylinders, 3);
    expect(withStats.single.trip.divesPerDayTarget, 2);

    await repo.updateTrip(
      byId.copyWith(diversSharingCylinders: 1, divesPerDayTarget: null),
    );
    final cleared = await repo.getTripById(created.id);
    expect(cleared!.diversSharingCylinders, 1);
    expect(cleared.divesPerDayTarget, isNull);
  });

  test('a failed itinerary cleanup does not fail the trip save', () async {
    // The trip row is written and queued before the cleanup runs; a
    // cleanup failure must not report that saved edit as failed.
    final repo = TripRepository(itineraryDays: _FailingCleanup());
    final created = await repo.createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await repo.updateTrip(created.copyWith(name: 'Bonaire, shortened'));
    expect((await repo.getTripById(created.id))!.name, 'Bonaire, shortened');
  });
}

/// Cannot drop plan-only itinerary days.
class _FailingCleanup extends ItineraryDayRepository {
  @override
  Future<void> deleteBarePlanDaysOutside(
    String tripId,
    DateTime start,
    DateTime end,
  ) async => throw StateError('database locked');
}
