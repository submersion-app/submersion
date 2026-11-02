import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';
import 'record_harness.dart';

void main() {
  late AppDatabase db;
  late RecordHarness h;
  const t = kSeedTime;

  Future<void> trip(
    String id,
    String owner, {
    bool shared = false,
    String? parent,
  }) => db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: id,
          name: id,
          startDate: DateTime(2024, 3, 1).millisecondsSinceEpoch,
          endDate: DateTime(2024, 3, 8).millisecondsSinceEpoch,
          createdAt: t,
          updatedAt: t,
          diverId: Value(owner),
          isShared: Value(shared),
          parentTripId: Value(parent),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    await trip('mine', kDiverA);
    await trip('theirs', kDiverB);
    await trip('open', kDiverB, shared: true);
    await trip('named', kDiverB);
    await db
        .into(db.tripShares)
        .insert(
          TripSharesCompanion.insert(
            id: 'share',
            tripId: 'named',
            diverId: kDiverA,
            createdAt: t,
          ),
        );
    for (final id in ['mine', 'theirs', 'open']) {
      await db
          .into(db.tripItineraryDays)
          .insert(
            TripItineraryDaysCompanion.insert(
              id: 'day-$id',
              tripId: id,
              dayNumber: 1,
              date: DateTime(2024, 3, 2).millisecondsSinceEpoch,
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.liveaboardDetailRecords)
          .insert(
            LiveaboardDetailRecordsCompanion.insert(
              id: 'boat-$id',
              tripId: id,
              vesselName: 'Sea Star',
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.tripCylinders)
          .insert(
            TripCylindersCompanion.insert(
              id: 'cyl-$id',
              tripId: id,
              label: const Value('Twin 12'),
              volume: const Value(12),
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.tripCylinderEvents)
          .insert(
            TripCylinderEventsCompanion.insert(
              id: 'evt-$id',
              tripCylinderId: 'cyl-$id',
              kind: 'fill',
              occurredAt: t,
              pressure: const Value(220),
              o2Percent: const Value(32),
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.tripChecklistSections)
          .insert(
            TripChecklistSectionsCompanion.insert(
              id: 'sec-$id',
              tripId: id,
              title: 'Packing',
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.tripChecklistItems)
          .insert(
            TripChecklistItemsCompanion.insert(
              id: 'chk-$id',
              tripId: id,
              title: 'Passport',
              sectionId: Value('sec-$id'),
              dueDate: Value(DateTime(2024, 2, 20).millisecondsSinceEpoch),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    for (final (id, owner, tripId) in [
      ('d-a', kDiverA, 'open'),
      ('d-b', kDiverB, 'open'),
    ]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
              tripId: Value(tripId),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  group('trips', () {
    test('start and end are calendar dates', () async {
      final doc = (await h.one('trips', 'mine'))!;
      expect(doc['start_date'], '2024-03-01');
      expect(doc['end_date'], '2024-03-08');
    });

    test('return_flight_time keeps its wall clock', () async {
      await (db.update(db.trips)..where((x) => x.id.equals('mine'))).write(
        const TripsCompanion(returnFlightAt: Value(0)),
      );
      final doc = (await h.one('trips', 'mine'))!;
      expect(doc['return_flight_time'], '1970-01-01T00:00:00.000Z');
    });

    test('a shared trip reads for a share row holder', () async {
      expect(await h.one('trips', 'named'), isNotNull);
      expect(await h.one('trips', 'theirs'), isNull);
    });

    test('a hidden trip hides its children', () async {
      expect(await h.one('itinerary_days', 'day-open'), isNotNull);
      await db
          .into(db.tripHides)
          .insert(
            TripHidesCompanion.insert(
              id: 'hide',
              tripId: 'open',
              diverId: kDiverA,
              createdAt: t,
            ),
          );
      expect(await h.one('trips', 'open'), isNull);
      expect(await h.one('itinerary_days', 'day-open'), isNull);
      expect(await h.one('trip_cylinder_events', 'evt-open'), isNull);
    });

    test('dive_ids lists only what the diver sees', () async {
      final doc = (await h.one('trips', 'open', include: ['dive_ids']))!;
      expect(doc['dive_ids'], ['d-a']);
    });

    test('blocks arrive when named', () async {
      final doc = (await h.one(
        'trips',
        'mine',
        include: [
          'itinerary',
          'liveaboard',
          'cylinders',
          'checklist',
          'side_trips',
          'shares',
          'equipment_ids',
        ],
      ))!;
      expect((doc['itinerary'] as List).cast<Map>().single['id'], 'day-mine');
      expect((doc['liveaboard'] as Map)['vessel_name'], 'Sea Star');
      expect((doc['cylinders'] as List).cast<Map>().single['id'], 'cyl-mine');
      final checklist = doc['checklist'] as Map;
      expect((checklist['sections'] as List), hasLength(1));
      expect((checklist['items'] as List), hasLength(1));
      expect(doc['side_trips'], isEmpty);
      expect(doc['shares'], isEmpty);
      expect(doc['equipment_ids'], isEmpty);
    });

    test('equipment_ids leaves out gear the diver cannot see', () async {
      for (final (id, owner) in [('own-reg', kDiverA), ('b-reg', kDiverB)]) {
        await db
            .into(db.equipment)
            .insert(
              EquipmentCompanion.insert(
                id: id,
                name: id,
                type: 'regulator',
                createdAt: t,
                updatedAt: t,
                diverId: Value(owner),
              ),
            );
        await db
            .into(db.tripEquipment)
            .insert(
              TripEquipmentCompanion.insert(
                id: 'pack-$id',
                tripId: 'open',
                equipmentId: id,
                createdAt: t,
              ),
            );
      }
      final doc = (await h.one('trips', 'open', include: ['equipment_ids']))!;
      expect(doc['equipment_ids'], ['own-reg']);
    });

    test('side_trips names the children of a trip', () async {
      await trip('side', kDiverA, parent: 'mine');
      await (db.update(db.trips)..where((x) => x.id.equals('side'))).write(
        TripsCompanion(
          startDate: Value(DateTime(2024, 3, 2).millisecondsSinceEpoch),
          endDate: Value(DateTime(2024, 3, 3).millisecondsSinceEpoch),
        ),
      );
      final doc = (await h.one('trips', 'mine', include: ['side_trips']))!;
      expect((doc['side_trips'] as List).cast<Map>().single['id'], 'side');
    });

    test('scope matches getAllTrips', () async {
      final expected = {
        for (final x in await TripRepository().getAllTrips(diverId: kDiverA))
          x.id,
      };
      final out = await h.get('trips', ['mine', 'theirs', 'open', 'named']);
      expect(
        (out['records'] as List).cast<Map>().map((r) => r['id']).toSet(),
        expected,
      );
    });
  });

  group('trip children', () {
    for (final (entity, own, other) in [
      ('itinerary_days', 'day-mine', 'day-theirs'),
      ('liveaboard_details', 'boat-mine', 'boat-theirs'),
      ('trip_cylinders', 'cyl-mine', 'cyl-theirs'),
      ('trip_checklist_sections', 'sec-mine', 'sec-theirs'),
      ('trip_checklist_items', 'chk-mine', 'chk-theirs'),
    ]) {
      test('$entity reads by id and stops at the profile', () async {
        expect((await h.one(entity, own))!['trip_id'], 'mine');
        expect(await h.one(entity, other), isNull);
      });

      test('$entity lists by trip', () async {
        expect(await h.list(entity, parentId: 'mine'), [own]);
        expect(await h.list(entity, parentId: 'theirs'), isEmpty);
      });
    }

    test('cylinder events read through a shared trip', () async {
      final doc = (await h.one('trip_cylinder_events', 'evt-open'))!;
      expect(doc['trip_cylinder_id'], 'cyl-open');
      expect(doc['pressure_bar'], 220.0);
      expect(doc['o2_fraction'], closeTo(0.32, 1e-9));
      expect(doc['occurred_time'], endsWith('Z'));
      expect(doc.keys, isNot(contains('occurred_at')));
      expect(await h.one('trip_cylinder_events', 'evt-theirs'), isNull);
      expect(await h.list('trip_cylinder_events', parentId: 'cyl-open'), [
        'evt-open',
      ]);
    });

    test('a day and a due date are calendar dates', () async {
      expect(
        (await h.one('itinerary_days', 'day-mine'))!['day_date'],
        '2024-03-02',
      );
      expect(
        (await h.one('trip_checklist_items', 'chk-mine'))!['due_date'],
        '2024-02-20',
      );
    });

    test('a trip cylinder keeps volume_l', () async {
      expect((await h.one('trip_cylinders', 'cyl-mine'))!['volume_l'], 12.0);
    });
  });
}
