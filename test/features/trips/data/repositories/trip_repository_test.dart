import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late TripRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = TripRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Trip createTestTrip({
    String id = '',
    String name = 'Test Trip',
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? resortName,
    String? liveaboardName,
    String notes = '',
  }) {
    final now = DateTime.now();
    final start = startDate ?? now;
    final end = endDate ?? now.add(const Duration(days: 7));
    return Trip(
      id: id,
      name: name,
      startDate: start,
      endDate: end,
      location: location,
      resortName: resortName,
      liveaboardName: liveaboardName,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('TripRepository', () {
    group('createTrip', () {
      test('should create a new trip with generated ID when ID is empty', () async {
        final trip = createTestTrip(name: 'Maldives Adventure');

        final createdTrip = await repository.createTrip(trip);

        expect(createdTrip.id, isNotEmpty);
        expect(createdTrip.name, equals('Maldives Adventure'));
      });

      test('should create a trip with provided ID', () async {
        final trip = createTestTrip(id: 'custom-trip-id', name: 'Red Sea Expedition');

        final createdTrip = await repository.createTrip(trip);

        expect(createdTrip.id, equals('custom-trip-id'));
      });

      test('should create a trip with all fields', () async {
        final startDate = DateTime(2024, 6, 1);
        final endDate = DateTime(2024, 6, 8);
        final trip = createTestTrip(
          name: 'Full Details Trip',
          startDate: startDate,
          endDate: endDate,
          location: 'Maldives',
          resortName: 'Dive Resort XYZ',
          liveaboardName: null,
          notes: 'Amazing trip!',
        );

        final createdTrip = await repository.createTrip(trip);
        final fetchedTrip = await repository.getTripById(createdTrip.id);

        expect(fetchedTrip, isNotNull);
        expect(fetchedTrip!.name, equals('Full Details Trip'));
        expect(fetchedTrip.location, equals('Maldives'));
        expect(fetchedTrip.resortName, equals('Dive Resort XYZ'));
        expect(fetchedTrip.notes, equals('Amazing trip!'));
      });

      test('should create a liveaboard trip', () async {
        final trip = createTestTrip(
          name: 'Liveaboard Trip',
          liveaboardName: 'MY Ocean Explorer',
          location: 'Galapagos',
        );

        final createdTrip = await repository.createTrip(trip);
        final fetchedTrip = await repository.getTripById(createdTrip.id);

        expect(fetchedTrip, isNotNull);
        expect(fetchedTrip!.liveaboardName, equals('MY Ocean Explorer'));
        expect(fetchedTrip.location, equals('Galapagos'));
      });
    });

    group('getTripById', () {
      test('should return trip when found', () async {
        final trip = await repository.createTrip(createTestTrip(name: 'Find Me Trip'));

        final result = await repository.getTripById(trip.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Find Me Trip'));
      });

      test('should return null when trip not found', () async {
        final result = await repository.getTripById('non-existent-id');

        expect(result, isNull);
      });
    });

    group('getAllTrips', () {
      test('should return empty list when no trips exist', () async {
        final result = await repository.getAllTrips();

        expect(result, isEmpty);
      });

      test('should return all trips ordered by start date (newest first)', () async {
        final trip1 = createTestTrip(
          name: 'January Trip',
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 7),
        );
        final trip2 = createTestTrip(
          name: 'June Trip',
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 7),
        );
        final trip3 = createTestTrip(
          name: 'March Trip',
          startDate: DateTime(2024, 3, 1),
          endDate: DateTime(2024, 3, 7),
        );

        await repository.createTrip(trip1);
        await repository.createTrip(trip2);
        await repository.createTrip(trip3);

        final result = await repository.getAllTrips();

        expect(result.length, equals(3));
        expect(result[0].name, equals('June Trip'));
        expect(result[1].name, equals('March Trip'));
        expect(result[2].name, equals('January Trip'));
      });
    });

    group('updateTrip', () {
      test('should update trip fields', () async {
        final trip = await repository.createTrip(createTestTrip(
          name: 'Original Name',
          location: 'Original Location',
        ));

        final updatedTrip = trip.copyWith(
          name: 'Updated Name',
          location: 'Updated Location',
          notes: 'Updated notes',
        );

        await repository.updateTrip(updatedTrip);
        final result = await repository.getTripById(trip.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Updated Name'));
        expect(result.location, equals('Updated Location'));
        expect(result.notes, equals('Updated notes'));
      });

      test('should update date range', () async {
        final trip = await repository.createTrip(createTestTrip(
          name: 'Date Update Trip',
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 7),
        ));

        final newStartDate = DateTime(2024, 2, 1);
        final newEndDate = DateTime(2024, 2, 14);
        final updatedTrip = trip.copyWith(
          startDate: newStartDate,
          endDate: newEndDate,
        );

        await repository.updateTrip(updatedTrip);
        final result = await repository.getTripById(trip.id);

        expect(result!.startDate.year, equals(2024));
        expect(result.startDate.month, equals(2));
        expect(result.startDate.day, equals(1));
        expect(result.endDate.day, equals(14));
      });
    });

    group('deleteTrip', () {
      test('should delete existing trip', () async {
        final trip = await repository.createTrip(createTestTrip(name: 'To Delete'));

        await repository.deleteTrip(trip.id);
        final result = await repository.getTripById(trip.id);

        expect(result, isNull);
      });

      test('should not throw when deleting non-existent trip', () async {
        await expectLater(
          repository.deleteTrip('non-existent-id'),
          completes,
        );
      });
    });

    group('searchTrips', () {
      setUp(() async {
        await repository.createTrip(createTestTrip(
          name: 'Maldives Adventure',
          location: 'Maldives',
          resortName: 'Ocean Paradise Resort',
        ));
        await repository.createTrip(createTestTrip(
          name: 'Red Sea Expedition',
          location: 'Egypt',
          liveaboardName: 'MY Red Sea Explorer',
        ));
        await repository.createTrip(createTestTrip(
          name: 'Caribbean Dive Trip',
          location: 'Bonaire',
          resortName: 'Caribbean Divers',
        ));
      });

      test('should find trips by name', () async {
        final results = await repository.searchTrips('Adventure');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Maldives Adventure'));
      });

      test('should find trips by location', () async {
        final results = await repository.searchTrips('Egypt');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Red Sea Expedition'));
      });

      test('should find trips by resort name', () async {
        final results = await repository.searchTrips('Paradise');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Maldives Adventure'));
      });

      test('should find trips by liveaboard name', () async {
        final results = await repository.searchTrips('Explorer');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Red Sea Expedition'));
      });

      test('should return empty list for no matches', () async {
        final results = await repository.searchTrips('NonExistent');

        expect(results, isEmpty);
      });

      test('should be case insensitive', () async {
        final results = await repository.searchTrips('MALDIVES');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Maldives Adventure'));
      });
    });

    group('findTripForDate', () {
      test('should find trip containing the given date', () async {
        final trip = await repository.createTrip(createTestTrip(
          name: 'June Trip',
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 15),
        ));

        final result = await repository.findTripForDate(DateTime(2024, 6, 10));

        expect(result, isNotNull);
        expect(result!.id, equals(trip.id));
      });

      test('should return null when no trip contains the date', () async {
        await repository.createTrip(createTestTrip(
          name: 'June Trip',
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 15),
        ));

        final result = await repository.findTripForDate(DateTime(2024, 7, 10));

        expect(result, isNull);
      });

      test('should include start date', () async {
        final trip = await repository.createTrip(createTestTrip(
          name: 'June Trip',
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 15),
        ));

        final result = await repository.findTripForDate(DateTime(2024, 6, 1));

        expect(result, isNotNull);
        expect(result!.id, equals(trip.id));
      });

      test('should include end date', () async {
        final trip = await repository.createTrip(createTestTrip(
          name: 'June Trip',
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 15),
        ));

        final result = await repository.findTripForDate(DateTime(2024, 6, 15));

        expect(result, isNotNull);
        expect(result!.id, equals(trip.id));
      });
    });

    group('getDiveCountForTrip', () {
      test('should return 0 when trip has no dives', () async {
        final trip = await repository.createTrip(createTestTrip(name: 'Empty Trip'));

        final count = await repository.getDiveCountForTrip(trip.id);

        expect(count, equals(0));
      });
    });

    group('getTripWithStats', () {
      test('should return stats with zero values for trip with no dives', () async {
        final trip = await repository.createTrip(createTestTrip(name: 'Stats Trip'));

        final stats = await repository.getTripWithStats(trip.id);

        expect(stats.trip.id, equals(trip.id));
        expect(stats.diveCount, equals(0));
        expect(stats.totalBottomTime, equals(0));
        expect(stats.maxDepth, isNull);
        expect(stats.avgDepth, isNull);
      });

      test('should throw when trip not found', () async {
        expect(
          () => repository.getTripWithStats('non-existent-id'),
          throwsException,
        );
      });
    });

    group('getAllTripsWithStats', () {
      test('should return empty list when no trips exist', () async {
        final result = await repository.getAllTripsWithStats();

        expect(result, isEmpty);
      });

      test('should return all trips with stats', () async {
        await repository.createTrip(createTestTrip(name: 'Trip 1'));
        await repository.createTrip(createTestTrip(name: 'Trip 2'));

        final result = await repository.getAllTripsWithStats();

        expect(result.length, equals(2));
        expect(result.every((t) => t.diveCount == 0), isTrue);
      });
    });

    group('getDiveIdsForTrip', () {
      test('should return empty list when trip has no dives', () async {
        final trip = await repository.createTrip(createTestTrip(name: 'No Dives Trip'));

        final diveIds = await repository.getDiveIdsForTrip(trip.id);

        expect(diveIds, isEmpty);
      });
    });
  });
}
