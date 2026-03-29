import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('ItineraryDayRepository error handling', () {
    late ItineraryDayRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = ItineraryDayRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final day = ItineraryDay(
        id: 'id1',
        tripId: 't1',
        dayNumber: 1,
        date: now,
        dayType: DayType.diveDay,
        createdAt: now,
        updatedAt: now,
      );

      // getByTripId - rethrows
      await expectLater(repository.getByTripId('t1'), throwsA(anything));

      // saveAll - rethrows
      await expectLater(repository.saveAll([day]), throwsA(anything));

      // updateDay - rethrows
      await expectLater(repository.updateDay(day), throwsA(anything));

      // deleteByTripId - rethrows
      await expectLater(repository.deleteByTripId('t1'), throwsA(anything));

      // regenerateForTrip - rethrows
      await expectLater(
        repository.regenerateForTrip(
          't1',
          now,
          now.add(const Duration(days: 7)),
        ),
        throwsA(anything),
      );
    });
  });
}
