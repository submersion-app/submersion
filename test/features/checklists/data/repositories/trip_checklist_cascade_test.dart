import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('deleting a trip atomically deletes liveaboard details, itinerary '
      'days, and checklist items, and tombstones all of them', () async {
    final tripRepository = TripRepository();
    final checklistRepository = TripChecklistRepository();
    final liveaboardRepository = LiveaboardDetailsRepository();
    final itineraryRepository = ItineraryDayRepository();

    final trip = await tripRepository.createTrip(
      Trip(
        id: '',
        name: 'Cascade',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 17),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final item = await checklistRepository.createItem(
      TripChecklistItem(
        id: '',
        tripId: trip.id,
        title: 'Pack fins',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final liveaboard = await liveaboardRepository.createOrUpdate(
      LiveaboardDetails(
        id: '',
        tripId: trip.id,
        vesselName: 'MV Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await itineraryRepository.saveAll([
      ItineraryDay(
        id: '',
        tripId: trip.id,
        dayNumber: 1,
        date: trip.startDate,
        dayType: DayType.embark,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);
    final itineraryDays = await itineraryRepository.getByTripId(trip.id);
    expect(itineraryDays, hasLength(1));
    final itineraryDayId = itineraryDays.first.id;

    await tripRepository.deleteTrip(trip.id);

    // Every child record is gone (FK would also have blocked the trip
    // delete otherwise, since the cascades run before the trip row does).
    expect(await checklistRepository.getByTripId(trip.id), isEmpty);
    expect(await liveaboardRepository.getByTripId(trip.id), isNull);
    expect(await itineraryRepository.getByTripId(trip.id), isEmpty);
    expect(await tripRepository.getTripById(trip.id), isNull);

    // Tombstones written for every deleted child and the trip itself.
    final db = DatabaseService.instance.database;
    Future<List<String>> recordIdsFor(String entityType) async {
      final rows = await db
          .customSelect(
            'SELECT record_id FROM deletion_log WHERE entity_type = ?',
            variables: [Variable.withString(entityType)],
          )
          .get();
      return rows.map((r) => r.read<String>('record_id')).toList();
    }

    expect(await recordIdsFor('tripChecklistItems'), contains(item.id));
    expect(await recordIdsFor('liveaboardDetails'), contains(liveaboard.id));
    expect(await recordIdsFor('itineraryDays'), contains(itineraryDayId));
    expect(await recordIdsFor('trips'), contains(trip.id));
  });

  test('deleting a trip that does not exist does not tombstone any child '
      'records (each child cascade sees an empty result and skips)', () async {
    final tripRepository = TripRepository();
    final db = DatabaseService.instance.database;

    Future<int> countFor(String entityType) async {
      final row = await db
          .customSelect(
            'SELECT COUNT(*) as c FROM deletion_log WHERE entity_type = ?',
            variables: [Variable.withString(entityType)],
          )
          .getSingle();
      return row.read<int>('c');
    }

    const childEntityTypes = [
      'tripChecklistItems',
      'liveaboardDetails',
      'itineraryDays',
    ];
    final before = {
      for (final type in childEntityTypes) type: await countFor(type),
    };

    // No trip with this id exists; every child cascade
    // (LiveaboardDetailsRepository/ItineraryDayRepository/
    // TripChecklistRepository.deleteByTripId) queries by tripId first and
    // returns early on an empty result, so none of them should write a
    // tombstone for a record that never existed. (The outer trip-level
    // logDeletion is unconditional and pre-existing behavior -- not
    // asserted here since it is orthogonal to the child cascades this
    // transaction wrapper protects.)
    await tripRepository.deleteTrip('does-not-exist');

    for (final type in childEntityTypes) {
      expect(
        await countFor(type),
        before[type],
        reason: 'deleteTrip on a nonexistent id must not tombstone $type',
      );
    }
  });
}
