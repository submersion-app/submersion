import 'package:flutter_test/flutter_test.dart';
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
}
