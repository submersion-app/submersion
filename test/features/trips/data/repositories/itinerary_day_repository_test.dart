import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ItineraryDayRepository repository;
  late TripRepository tripRepository;
  late String testTripId;

  final startDate = DateTime(2025, 3, 1);
  final endDate = DateTime(2025, 3, 7);

  Trip createTestTrip({String id = '', String name = 'Test Trip'}) {
    final now = DateTime.now();
    return Trip(
      id: id,
      name: name,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
      updatedAt: now,
    );
  }

  ItineraryDay createTestDay({
    String id = '',
    String? tripId,
    int dayNumber = 1,
    DateTime? date,
    DayType dayType = DayType.diveDay,
    String? portName,
    double? latitude,
    double? longitude,
    String notes = '',
  }) {
    final now = DateTime.now();
    return ItineraryDay(
      id: id,
      tripId: tripId ?? testTripId,
      dayNumber: dayNumber,
      date: date ?? startDate,
      dayType: dayType,
      portName: portName,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async {
    await setUpTestDatabase();
    repository = ItineraryDayRepository();
    tripRepository = TripRepository();

    // Create a trip to satisfy FK constraint
    final trip = await tripRepository.createTrip(
      createTestTrip(name: 'Itinerary Test Trip'),
    );
    testTripId = trip.id;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('ItineraryDayRepository', () {
    group('getByTripId', () {
      test('should return empty list when no days exist', () async {
        final result = await repository.getByTripId(testTripId);

        expect(result, isEmpty);
      });

      test('should return empty list for non-existent trip id', () async {
        final result = await repository.getByTripId('non-existent-id');

        expect(result, isEmpty);
      });

      // #2664: a stored day number is the one the trip's start gave the row
      // when it was written, so rows written under different starts are out
      // of order by number.
      test('should order days by date, not by stored day number', () async {
        await repository.saveAll([
          createTestDay(id: 'late', dayNumber: 1, date: DateTime(2025, 3, 6)),
          createTestDay(id: 'early', dayNumber: 7, date: DateTime(2025, 3, 2)),
        ]);

        final result = await repository.getByTripId(testTripId);

        expect(result.map((d) => d.id), ['early', 'late']);
      });
    });

    group('saveAll', () {
      test(
        'should save multiple days and getByTripId returns them ordered by dayNumber',
        () async {
          final days = [
            createTestDay(
              dayNumber: 3,
              date: DateTime(2025, 3, 3),
              dayType: DayType.diveDay,
            ),
            createTestDay(
              dayNumber: 1,
              date: DateTime(2025, 3, 1),
              dayType: DayType.embark,
            ),
            createTestDay(
              dayNumber: 2,
              date: DateTime(2025, 3, 2),
              dayType: DayType.diveDay,
            ),
          ];

          await repository.saveAll(days);
          final result = await repository.getByTripId(testTripId);

          expect(result, hasLength(3));
          expect(result[0].dayNumber, equals(1));
          expect(result[1].dayNumber, equals(2));
          expect(result[2].dayNumber, equals(3));
          expect(result[0].dayType, equals(DayType.embark));
          expect(result[1].dayType, equals(DayType.diveDay));
          expect(result[2].dayType, equals(DayType.diveDay));
        },
      );

      test('should generate UUID for days with empty id', () async {
        final days = [
          createTestDay(id: '', dayNumber: 1, date: DateTime(2025, 3, 1)),
        ];

        await repository.saveAll(days);
        final result = await repository.getByTripId(testTripId);

        expect(result, hasLength(1));
        expect(result[0].id, isNotEmpty);
      });

      test('should save days with all fields', () async {
        final days = [
          createTestDay(
            dayNumber: 1,
            date: DateTime(2025, 3, 1),
            dayType: DayType.portDay,
            portName: 'Male Harbor',
            latitude: 4.1755,
            longitude: 73.5093,
            notes: 'Departure port',
          ),
        ];

        await repository.saveAll(days);
        final result = await repository.getByTripId(testTripId);

        expect(result, hasLength(1));
        expect(result[0].dayType, equals(DayType.portDay));
        expect(result[0].portName, equals('Male Harbor'));
        expect(result[0].latitude, closeTo(4.1755, 0.001));
        expect(result[0].longitude, closeTo(73.5093, 0.001));
        expect(result[0].notes, equals('Departure port'));
      });
    });

    group('updateDay', () {
      test(
        'should update dayType, portName, and notes for a single day',
        () async {
          final days = [
            createTestDay(
              dayNumber: 1,
              date: DateTime(2025, 3, 1),
              dayType: DayType.diveDay,
              notes: 'Original notes',
            ),
          ];

          await repository.saveAll(days);
          final saved = await repository.getByTripId(testTripId);
          final dayToUpdate = saved[0].copyWith(
            dayType: DayType.portDay,
            portName: 'Hurghada',
            notes: 'Updated notes',
          );

          await repository.updateDay(dayToUpdate);
          final result = await repository.getByTripId(testTripId);

          expect(result, hasLength(1));
          expect(result[0].dayType, equals(DayType.portDay));
          expect(result[0].portName, equals('Hurghada'));
          expect(result[0].notes, equals('Updated notes'));
        },
      );

      test('should update latitude and longitude', () async {
        final days = [createTestDay(dayNumber: 1, date: DateTime(2025, 3, 1))];

        await repository.saveAll(days);
        final saved = await repository.getByTripId(testTripId);
        final dayToUpdate = saved[0].copyWith(
          latitude: 27.2579,
          longitude: 33.8116,
        );

        await repository.updateDay(dayToUpdate);
        final result = await repository.getByTripId(testTripId);

        expect(result[0].latitude, closeTo(27.2579, 0.001));
        expect(result[0].longitude, closeTo(33.8116, 0.001));
      });

      test('should preserve createdAt when updating', () async {
        final days = [createTestDay(dayNumber: 1, date: DateTime(2025, 3, 1))];

        await repository.saveAll(days);
        final saved = await repository.getByTripId(testTripId);
        final originalCreatedAt = saved[0].createdAt;

        // Small delay so updatedAt would differ
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final dayToUpdate = saved[0].copyWith(notes: 'New notes');
        await repository.updateDay(dayToUpdate);
        final result = await repository.getByTripId(testTripId);

        expect(
          result[0].createdAt.millisecondsSinceEpoch,
          equals(originalCreatedAt.millisecondsSinceEpoch),
        );
        expect(result[0].notes, equals('New notes'));
      });
    });

    group('deleteByTripId', () {
      test('should remove all days for a trip', () async {
        final days = [
          createTestDay(dayNumber: 1, date: DateTime(2025, 3, 1)),
          createTestDay(dayNumber: 2, date: DateTime(2025, 3, 2)),
          createTestDay(dayNumber: 3, date: DateTime(2025, 3, 3)),
        ];

        await repository.saveAll(days);

        // Verify days exist
        final beforeDelete = await repository.getByTripId(testTripId);
        expect(beforeDelete, hasLength(3));

        await repository.deleteByTripId(testTripId);

        final afterDelete = await repository.getByTripId(testTripId);
        expect(afterDelete, isEmpty);
      });

      test('should be a no-op when no days exist', () async {
        await expectLater(repository.deleteByTripId(testTripId), completes);
      });

      test('should be a no-op for non-existent trip id', () async {
        await expectLater(
          repository.deleteByTripId('non-existent-trip'),
          completes,
        );
      });
    });

    group('regenerateForTrip', () {
      test('types the days for the trip, not for a boat', () async {
        final result = await repository.regenerateForTrip(
          testTripId,
          DateTime(2025, 3, 1),
          DateTime(2025, 3, 5),
          tripType: TripType.resort,
        );
        expect(result.first.dayType, DayType.travel);
        expect(result.last.dayType, DayType.travel);
      });

      test('should generate correct days for date range', () async {
        final result = await repository.regenerateForTrip(
          testTripId,
          DateTime(2025, 3, 1),
          DateTime(2025, 3, 5),
          tripType: TripType.liveaboard,
        );

        expect(result, hasLength(5));
        expect(result[0].dayNumber, equals(1));
        expect(result[0].dayType, equals(DayType.embark));
        expect(result[0].date, equals(DateTime(2025, 3, 1)));

        expect(result[1].dayNumber, equals(2));
        expect(result[1].dayType, equals(DayType.diveDay));

        expect(result[2].dayNumber, equals(3));
        expect(result[2].dayType, equals(DayType.diveDay));

        expect(result[3].dayNumber, equals(4));
        expect(result[3].dayType, equals(DayType.diveDay));

        expect(result[4].dayNumber, equals(5));
        expect(result[4].dayType, equals(DayType.disembark));
        expect(result[4].date, equals(DateTime(2025, 3, 5)));

        // Verify they are persisted
        final fetched = await repository.getByTripId(testTripId);
        expect(fetched, hasLength(5));
      });

      test(
        'should preserve notes and dayType from overlapping dates when range changes',
        () async {
          // First, generate days for March 1-5
          await repository.regenerateForTrip(
            testTripId,
            DateTime(2025, 3, 1),
            DateTime(2025, 3, 5),
            tripType: TripType.liveaboard,
          );

          // Customize day 2 (March 2) and day 3 (March 3)
          final existingDays = await repository.getByTripId(testTripId);
          final day2 = existingDays[1].copyWith(
            dayType: DayType.portDay,
            portName: 'Hurghada',
            latitude: 27.2579,
            longitude: 33.8116,
            notes: 'Port call for supplies',
          );
          final day3 = existingDays[2].copyWith(
            notes: 'Great visibility expected',
          );
          await repository.updateDay(day2);
          await repository.updateDay(day3);

          // Now regenerate for March 2-6 (shifted range)
          final result = await repository.regenerateForTrip(
            testTripId,
            DateTime(2025, 3, 2),
            DateTime(2025, 3, 6),
            tripType: TripType.liveaboard,
          );

          expect(result, hasLength(5));

          // March 2 is now Day 1 (embark), but should preserve portName,
          // latitude, longitude, notes from the old day. dayType should
          // come from the old day.
          expect(result[0].dayNumber, equals(1));
          expect(result[0].date, equals(DateTime(2025, 3, 2)));
          expect(result[0].dayType, equals(DayType.portDay));
          expect(result[0].portName, equals('Hurghada'));
          expect(result[0].latitude, closeTo(27.2579, 0.001));
          expect(result[0].longitude, closeTo(33.8116, 0.001));
          expect(result[0].notes, equals('Port call for supplies'));

          // March 3 is now Day 2, should preserve notes
          expect(result[1].dayNumber, equals(2));
          expect(result[1].date, equals(DateTime(2025, 3, 3)));
          expect(result[1].notes, equals('Great visibility expected'));

          // March 4-6 are new days with no overlap
          expect(result[2].dayNumber, equals(3));
          expect(result[2].notes, isEmpty);
          expect(result[3].dayNumber, equals(4));
          expect(result[4].dayNumber, equals(5));
          expect(result[4].dayType, equals(DayType.disembark));
        },
      );

      test('should work with no existing days', () async {
        final result = await repository.regenerateForTrip(
          testTripId,
          DateTime(2025, 3, 1),
          DateTime(2025, 3, 3),
          tripType: TripType.liveaboard,
        );

        expect(result, hasLength(3));
        expect(result[0].dayType, equals(DayType.embark));
        expect(result[1].dayType, equals(DayType.diveDay));
        expect(result[2].dayType, equals(DayType.disembark));
      });

      test('should replace all old days with new ones', () async {
        // Generate initial 7-day itinerary
        await repository.regenerateForTrip(
          testTripId,
          DateTime(2025, 3, 1),
          DateTime(2025, 3, 7),
          tripType: TripType.liveaboard,
        );
        final initial = await repository.getByTripId(testTripId);
        expect(initial, hasLength(7));

        // Regenerate with shorter range
        await repository.regenerateForTrip(
          testTripId,
          DateTime(2025, 3, 1),
          DateTime(2025, 3, 3),
          tripType: TripType.liveaboard,
        );
        final regenerated = await repository.getByTripId(testTripId);
        expect(regenerated, hasLength(3));
      });
    });

    group('planned dives (fill forecast)', () {
      test('a day with no row gets one, a dive day with its plan', () async {
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3, 14),
          plannedDives: 3,
        );
        final days = await repository.getByTripId(testTripId);
        expect(days, hasLength(1));
        expect(days.single.date, DateTime(2025, 3, 3));
        expect(days.single.dayNumber, 3);
        expect(days.single.dayType, DayType.diveDay);
        expect(days.single.plannedDives, 3);
      });

      test('a day with a row keeps it, its type and its notes', () async {
        await repository.saveAll([
          createTestDay(
            dayNumber: 4,
            date: DateTime(2025, 3, 4),
            dayType: DayType.portDay,
            notes: 'Kralendijk',
          ),
        ]);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 4),
          plannedDives: 1,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.portDay);
        expect(day.notes, 'Kralendijk');
        expect(day.plannedDives, 1);
      });

      test('null returns a day to the estimate and keeps its row', () async {
        final date = DateTime(2025, 3, 3);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: date,
          plannedDives: 3,
        );
        await repository.setPlannedDives(
          tripId: testTripId,
          date: date,
          plannedDives: null,
        );
        final days = await repository.getByTripId(testTripId);
        expect(days, hasLength(1));
        expect(days.single.plannedDives, isNull);
      });

      test('null on a day with no row writes nothing', () async {
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: null,
        );
        expect(await repository.getByTripId(testTripId), isEmpty);
      });

      test('two plans for one day at once leave one row', () async {
        // The table has no (trip, date) uniqueness; the find and the insert
        // share one transaction, so the second write finds the first row.
        final date = DateTime(2025, 3, 3);
        await Future.wait([
          repository.setPlannedDives(
            tripId: testTripId,
            date: date,
            plannedDives: 2,
          ),
          repository.setPlannedDives(
            tripId: testTripId,
            date: date,
            plannedDives: 4,
          ),
        ]);
        final days = await repository.getByTripId(testTripId);
        expect(days, hasLength(1));
        expect(days.single.plannedDives, 4);
      });

      test('a day with no row planned at 0 is typed Rest (#2658)', () async {
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: 0,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.rest);
        expect(day.plannedDives, 0);
      });

      test('a dive day planned at 0 becomes a Rest day', () async {
        await repository.saveAll([
          createTestDay(dayNumber: 3, date: DateTime(2025, 3, 3)),
        ]);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: 0,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.rest);
      });

      test('a Rest day planned at 2 becomes a dive day again (R1)', () async {
        await repository.saveAll([
          createTestDay(
            dayNumber: 3,
            date: DateTime(2025, 3, 3),
            dayType: DayType.rest,
          ),
        ]);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: 2,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.diveDay);
        expect(day.plannedDives, 2);
      });

      test('a Rest day returned to the estimate is a dive day again', () async {
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: 0,
        );
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: null,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.diveDay);
        expect(day.plannedDives, isNull);
      });

      test('a port day planned at 0 keeps its type', () async {
        await repository.saveAll([
          createTestDay(
            dayNumber: 4,
            date: DateTime(2025, 3, 4),
            dayType: DayType.portDay,
          ),
        ]);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 4),
          plannedDives: 0,
        );
        final day = (await repository.getByTripId(testTripId)).single;
        expect(day.dayType, DayType.portDay);
      });

      test('saveAll, updateDay and regenerateForTrip keep the plan', () async {
        await repository.saveAll([
          createTestDay(
            dayNumber: 3,
            date: DateTime(2025, 3, 3),
          ).copyWith(plannedDives: 2),
        ]);
        final saved = (await repository.getByTripId(testTripId)).single;
        expect(saved.plannedDives, 2);

        await repository.updateDay(saved.copyWith(notes: 'Klein Bonaire'));
        expect(
          (await repository.getByTripId(testTripId)).single.plannedDives,
          2,
        );

        await repository.regenerateForTrip(
          testTripId,
          startDate,
          endDate,
          tripType: TripType.liveaboard,
        );
        final regenerated = await repository.getByTripId(testTripId);
        final third = regenerated.firstWhere(
          (d) => d.date == DateTime(2025, 3, 3),
        );
        expect(third.plannedDives, 2);
        expect(regenerated.where((d) => d.plannedDives != null), hasLength(1));
      });

      test(
        'shortening the trip drops plan-only days it no longer has',
        () async {
          // A planned day on a shore trip is a bare row; left outside the
          // trip it would stretch the story to a day the trip no longer has.
          // A day with content stays, as orphaned days always have.
          await repository.setPlannedDives(
            tripId: testTripId,
            date: DateTime(2025, 3, 3),
            plannedDives: 2,
          );
          await repository.setPlannedDives(
            tripId: testTripId,
            date: DateTime(2025, 3, 7),
            plannedDives: 3,
          );
          await repository.saveAll([
            createTestDay(
              dayNumber: 6,
              date: DateTime(2025, 3, 6),
              dayType: DayType.portDay,
              portName: 'Kralendijk',
            ),
          ]);
          final trip = await tripRepository.getTripById(testTripId);
          await tripRepository.updateTrip(
            trip!.copyWith(endDate: DateTime(2025, 3, 5)),
          );
          final dates = [
            for (final d in await repository.getByTripId(testTripId)) d.date,
          ];
          expect(
            dates,
            unorderedEquals([DateTime(2025, 3, 3), DateTime(2025, 3, 6)]),
          );
        },
      );

      test('a blank note or port does not keep a plan-only day', () async {
        // Sync and import write the columns unnormalized, so whitespace is
        // as bare as empty; a real note still keeps its day (#2663).
        await repository.saveAll([
          createTestDay(dayNumber: 7, date: DateTime(2025, 3, 7), notes: ' '),
          createTestDay(
            dayNumber: 8,
            date: DateTime(2025, 3, 8),
            portName: ' ',
          ),
          createTestDay(
            dayNumber: 9,
            date: DateTime(2025, 3, 9),
            notes: 'Manta point',
          ),
        ]);
        final trip = await tripRepository.getTripById(testTripId);
        await tripRepository.updateTrip(
          trip!.copyWith(endDate: DateTime(2025, 3, 5)),
        );
        final dates = [
          for (final d in await repository.getByTripId(testTripId)) d.date,
        ];
        expect(dates, [DateTime(2025, 3, 9)]);
      });

      test('a plan reaches every row a date has', () async {
        // Two devices that planned one date offline leave two rows; the
        // edit must reach the one the forecast reads, whichever that is.
        await repository.saveAll([
          createTestDay(dayNumber: 3, date: DateTime(2025, 3, 3)),
          createTestDay(dayNumber: 3, date: DateTime(2025, 3, 3)),
        ]);
        await repository.setPlannedDives(
          tripId: testTripId,
          date: DateTime(2025, 3, 3),
          plannedDives: 3,
        );
        final days = await repository.getByTripId(testTripId);
        expect(days, hasLength(2));
        expect(days.map((d) => d.plannedDives), everyElement(3));
      });

      test('a plan for an unknown trip fails and writes nothing', () async {
        await expectLater(
          repository.setPlannedDives(
            tripId: 'no-such-trip',
            date: DateTime(2025, 3, 3),
            plannedDives: 2,
          ),
          throwsA(isA<StateError>()),
        );
        expect(await repository.getByTripId('no-such-trip'), isEmpty);
      });
    });
  });
}
