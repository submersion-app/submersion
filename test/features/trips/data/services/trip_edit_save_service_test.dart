import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Trip;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A trip page's sitting is written as one History entry, and writes only
/// what it changed (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late ItineraryDayRepository days;
  late LiveaboardDetailsRepository vessels;
  late TripEditSaveService service;
  final changeLog = ChangeLogRepository();

  Future<Trip> stored([String id = 't1']) async =>
      (await trips.getTripById(id))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT id, source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<void> revert(String operationId) async {
    final service = ChangeLogRevertService(afterDiveWrites: (_) {});
    await service.execute(await service.planOperation(operationId));
  }

  Future<({Trip before, Trip after})?> save(EditSession<Trip> session) =>
      service.save(
        tripId: session.stored.id,
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        actingDiverId: 'me',
      );

  ItineraryDay day(String id, DateTime date, {String notes = ''}) =>
      ItineraryDay(
        id: id,
        tripId: 't1',
        dayNumber: 1,
        date: date,
        dayType: DayType.diveDay,
        notes: notes,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  Future<List<DateTime>> dayDates() async => [
    for (final d in await days.getByTripId('t1')) d.date,
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    days = ItineraryDayRepository();
    trips = TripRepository(itineraryDays: days);
    vessels = LiveaboardDetailsRepository();
    service = TripEditSaveService(trips, days, vessels);
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('me'),
            name: Value('Me'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await trips.createTrip(
      Trip(
        id: 't1',
        diverId: 'me',
        name: 'Red Sea',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 8),
        location: 'Hurghada',
        tripType: TripType.liveaboard,
        notes: 'Calm',
        returnFlightAt: DateTime.utc(2026, 6, 9, 12),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await vessels.createOrUpdate(
      LiveaboardDetails(
        id: 'v1',
        tripId: 't1',
        vesselName: 'MV Blue',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await days.saveAll([
      day('i1', DateTime(2026, 6, 1), notes: 'Embark'),
      day('i2', DateTime(2026, 6, 4)),
      // A bare plan day: a dive day with nothing but its plan.
      day('i3', DateTime(2026, 6, 8)),
    ]);
    // What setup wrote is not a sitting.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('writes a location change as one History entry', () async {
    final session = EditSession(await stored())
      ..set(tripLocationField, 'Safaga');

    final result = await save(session);

    expect((await stored()).location, 'Safaga');
    expect(result!.before.location, 'Hurghada');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:trips:t1:header');
  });

  // One case per column the trip's update writes: a value changed in
  // storage during the sitting, on a field the diver did not touch,
  // survives the Save.
  final census = <String, ({String sql, bool Function(Trip) kept})>{
    'name': (
      sql: "UPDATE trips SET name = 'Renamed'",
      kept: (t) => t.name == 'Renamed',
    ),
    'start date': (
      sql: 'UPDATE trips SET start_date = 5000',
      kept: (t) => t.startDate.millisecondsSinceEpoch == 5000,
    ),
    'end date': (
      sql: 'UPDATE trips SET end_date = 9000',
      kept: (t) => t.endDate.millisecondsSinceEpoch == 9000,
    ),
    'location': (
      sql: "UPDATE trips SET location = 'Elsewhere'",
      kept: (t) => t.location == 'Elsewhere',
    ),
    'resort': (
      sql: "UPDATE trips SET resort_name = 'Oasis'",
      kept: (t) => t.resortName == 'Oasis',
    ),
    'liveaboard name': (
      sql: "UPDATE trips SET liveaboard_name = 'MV Old'",
      kept: (t) => t.liveaboardName == 'MV Old',
    ),
    'notes': (
      sql: "UPDATE trips SET notes = 'Newer'",
      kept: (t) => t.notes == 'Newer',
    ),
    'type': (
      sql: "UPDATE trips SET trip_type = 'resort'",
      kept: (t) => t.tripType == TripType.resort,
    ),
    'return flight': (
      sql: 'UPDATE trips SET return_flight_at = 7000',
      kept: (t) => t.returnFlightAt?.millisecondsSinceEpoch == 7000,
    ),
    'expected dives': (
      sql: 'UPDATE trips SET expected_dives = 20',
      kept: (t) => t.expectedDives == 20,
    ),
    'expected runtime': (
      sql: 'UPDATE trips SET expected_runtime_minutes = 50',
      kept: (t) => t.expectedRuntimeMinutes == 50,
    ),
    'divers sharing': (
      sql: 'UPDATE trips SET divers_sharing_cylinders = 3',
      kept: (t) => t.diversSharingCylinders == 3,
    ),
    'dives per day': (
      sql: 'UPDATE trips SET dives_per_day_target = 4',
      kept: (t) => t.divesPerDayTarget == 4,
    ),
  };
  for (final MapEntry(key: column, value: change) in census.entries) {
    test('a $column changed underneath keeps its newer value', () async {
      // The sitting changes a field other than the one changed underneath.
      final EditField<Trip, String> touched = column == 'notes'
          ? tripNameField
          : tripNotesField;
      final session = EditSession(await stored())..set(touched, 'Edited');
      await db.customStatement('${change.sql} WHERE id = ?', ['t1']);

      await save(session);

      final after = await stored();
      expect(change.kept(after), isTrue, reason: column);
      expect(touched.read(after), 'Edited');
    });
  }

  test('a parent changed underneath keeps its newer value', () async {
    await trips.createTrip(
      Trip(
        id: 'p1',
        diverId: 'me',
        name: 'Egypt',
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 6, 20),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final session = EditSession(await stored())..set(tripNotesField, 'Edited');
    await db.customStatement(
      "UPDATE trips SET parent_trip_id = 'p1' WHERE id = 't1'",
    );

    await save(session);

    expect((await stored()).parentTripId, 'p1');
  });

  test('clearing the return flight stores null', () async {
    final session = EditSession(await stored())
      ..set(tripReturnFlightField, null);

    await save(session);

    expect((await stored()).returnFlightAt, isNull);
  });

  test('a type made resort removes the vessel details in the same entry, '
      'and reverting restores them', () async {
    final session = EditSession(await stored())
      ..set(tripTypeField, TripType.resort);

    await save(session);

    expect(await vessels.getByTripId('t1'), isNull);
    final ops = await operations();
    expect(ops, hasLength(1));

    await revert(ops.single['id']! as String);

    expect((await vessels.getByTripId('t1'))?.vesselName, 'MV Blue');
    expect((await stored()).tripType, TripType.liveaboard);
  });

  test('a liveaboard kept a liveaboard keeps its vessel details', () async {
    final session = EditSession(await stored())..set(tripNotesField, 'Windy');

    await save(session);

    expect((await vessels.getByTripId('t1'))?.vesselName, 'MV Blue');
  });

  test('the end moved earlier drops the bare day outside in the same entry, '
      'and reverting restores it', () async {
    final session = EditSession(await stored())
      ..set(tripDatesField, (
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 7),
      ));

    await save(session);

    expect(await dayDates(), [DateTime(2026, 6, 1), DateTime(2026, 6, 4)]);
    final ops = await operations();
    expect(ops, hasLength(1));

    await revert(ops.single['id']! as String);

    expect(await dayDates(), [
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 4),
      DateTime(2026, 6, 8),
    ]);
    expect((await stored()).endDate, DateTime(2026, 6, 8));
  });

  test('the end moved earlier with a non-bare day edited outside the new '
      'dates: Save keeps the edited day, drops the bare one, one entry, and '
      'reverting restores both', () async {
    final session = EditSession(await stored());
    final list = tripItineraryDays(days);
    await list.load(session);
    // Day 8 gets notes, so it is no longer a bare plan day; day 4 stays.
    list.set(
      session,
      withDayEdited(
        list.current(session)!,
        (await days.getByTripId('t1')).last.copyWith(notes: 'Last wreck'),
      ),
    );
    session.set(tripDatesField, (
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 4),
    ));

    await service.save(
      tripId: 't1',
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      actingDiverId: 'me',
      alsoWrite: session.runHeldWrites,
      alsoWriteIsAChange: session.hasHeldChanges,
    );

    final after = await days.getByTripId('t1');
    expect([for (final d in after) d.id], ['i1', 'i2', 'i3']);
    expect(after.last.notes, 'Last wreck');
    final ops = await operations();
    expect(ops, hasLength(1));

    await revert(ops.single['id']! as String);

    expect((await days.getByTripId('t1')).last.notes, '');
    expect((await stored()).endDate, DateTime(2026, 6, 8));
  });

  test('a day edited inside the dates and a shortened trip drop only the '
      'bare day outside', () async {
    final session = EditSession(await stored());
    final list = tripItineraryDays(days);
    await list.load(session);
    list.set(
      session,
      withDayEdited(
        list.current(session)!,
        (await days.getByTripId('t1'))[1].copyWith(notes: 'Reef'),
      ),
    );
    session.set(tripDatesField, (
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 7),
    ));

    await service.save(
      tripId: 't1',
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      actingDiverId: 'me',
      alsoWrite: session.runHeldWrites,
      alsoWriteIsAChange: session.hasHeldChanges,
    );

    final after = await days.getByTripId('t1');
    expect([for (final d in after) d.id], ['i1', 'i2']);
    expect(after.last.notes, 'Reef');
  });

  test('a parent chosen drops foreign slot links on the trip dives', () async {
    final cylinders = TripCylinderRepository();
    await trips.createTrip(
      Trip(
        id: 'p1',
        diverId: 'me',
        name: 'Egypt',
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 6, 20),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await trips.createTrip(
      Trip(
        id: 'p2',
        diverId: 'me',
        name: 'Sinai',
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 6, 20),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final at = DateTime.utc(2026, 6, 3);
    final slot = (await cylinders.createCylinder(
      TripCylinder(
        id: '',
        tripId: 'p1',
        label: 'X',
        createdAt: at,
        updatedAt: at,
      ),
    )).id;
    await db.customStatement(
      "UPDATE trips SET parent_trip_id = 'p1' WHERE id = 't1'",
    );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: at.millisecondsSinceEpoch,
            tripId: const Value('t1'),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k1',
            diveId: 'd1',
          ).copyWith(tripCylinderId: Value(slot)),
        );
    final session = EditSession(await stored())..set(tripParentField, 'p2');

    await save(session);

    final link = await db
        .customSelect("SELECT trip_cylinder_id FROM dive_tanks WHERE id = 'k1'")
        .getSingle();
    expect(link.readNullable<String>('trip_cylinder_id'), isNull);
    expect((await stored()).parentTripId, 'p2');
  });

  test('unchanged returns null and writes nothing', () async {
    final result = await save(EditSession(await stored()));

    expect(result, isNull);
    expect(await operations(), isEmpty);
  });

  test('a trip that has gone throws', () async {
    final session = EditSession(await stored())
      ..set(tripLocationField, 'Safaga');
    // Gone on another device: its children went with it.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement("DELETE FROM trips WHERE id = 't1'");
    await db.customStatement('PRAGMA foreign_keys = ON');

    await expectLater(save(session), throwsStateError);
  });

  test('updateTrip with dropBarePlanDays false keeps a bare day outside the '
      'dates', () async {
    final trip = await stored();
    await trips.updateTrip(
      trip.copyWith(endDate: DateTime(2026, 6, 7)),
      dropBarePlanDays: false,
    );

    expect(await dayDates(), hasLength(3));
  });
}
