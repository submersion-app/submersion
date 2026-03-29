import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('TripRepository error handling', () {
    late TripRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = TripRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final trip = Trip(
        id: 't1',
        name: 'Test Trip',
        startDate: now,
        endDate: now.add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );

      // getAllTrips - rethrows
      await expectLater(repository.getAllTrips(), throwsA(anything));

      // getTripById - rethrows
      await expectLater(repository.getTripById('t1'), throwsA(anything));

      // createTrip - rethrows
      await expectLater(repository.createTrip(trip), throwsA(anything));

      // updateTrip - rethrows
      await expectLater(repository.updateTrip(trip), throwsA(anything));

      // deleteTrip - rethrows
      await expectLater(repository.deleteTrip('t1'), throwsA(anything));

      // assignDiveToTrip - rethrows
      await expectLater(
        repository.assignDiveToTrip('dive1', 't1'),
        throwsA(anything),
      );

      // removeDiveFromTrip - rethrows
      await expectLater(
        repository.removeDiveFromTrip('dive1'),
        throwsA(anything),
      );

      // findCandidateDivesForTrip - rethrows
      await expectLater(
        repository.findCandidateDivesForTrip(
          tripId: 't1',
          startDate: now,
          endDate: now.add(const Duration(days: 7)),
          diverId: 'diver1',
        ),
        throwsA(anything),
      );

      // assignDivesToTrip - rethrows
      await expectLater(
        repository.assignDivesToTrip(['dive1', 'dive2'], 't1'),
        throwsA(anything),
      );
    });
  });
}
