import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide Dive, DiveCenter, DiveCustomField, DiveWeight, Tag, Trip;
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// A new dive's sitting is created in one transaction and one change log
/// operation, with its held writes after the dive (issue #4527, plan 8).
void main() {
  late AppDatabase db;
  late DiveEditSaveService service;
  late DiveRepository dives;
  late TripRepository trips;
  final changeLog = ChangeLogRepository();
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);

  Dive seed(
    String id, {
    String notes = '',
    int? number,
    bool planned = false,
  }) => Dive(
    id: id,
    diverId: 'me',
    diveNumber: number,
    dateTime: DateTime.utc(2026, 11, 17, 9, 30),
    entryTime: DateTime.utc(2026, 11, 17, 9, 30),
    notes: notes,
    isPlanned: planned,
  );

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT id, source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    dives = DiveRepository();
    trips = TripRepository();
    service = DiveEditSaveService(dives, trips);
    await insertDiver(db, 'me');
    await insertDive(db, 'old', diverId: 'me', notes: 'Earlier');
    await db.customStatement(
      "UPDATE dives SET dive_number = 7 WHERE id = 'old'",
    );
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site',
            name: 'Lake',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await changeLog.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  test('creates the dive with its own id in one manual operation', () async {
    final result = await service.create(
      dive: seed('new-1', notes: 'Wall', number: 8),
      changedCardIds: ['notes'],
    );

    expect(result.after.id, 'new-1');
    expect((await dives.getDiveById('new-1'))!.notes, 'Wall');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(
      ops.single['label'],
      RecordEditLabel.encode(table: 'dives', id: 'new-1', cardIds: ['notes']),
    );
    expect(ops.single['source'], 'manual');
  });

  test('held writes run after the dive, inside the same operation', () async {
    Dive? seenByWrite;
    await service.create(
      dive: seed('new-1', number: 8),
      changedCardIds: ['notes'],
      alsoWrite: () async {
        seenByWrite = await dives.getDiveById('new-1');
        await db.customStatement(
          "UPDATE dive_sites SET altitude = 512 WHERE id = 'site'",
        );
      },
    );

    expect(seenByWrite, isNotNull);
    expect(await operations(), hasLength(1));
  });

  test('a held write that throws leaves no dive and no operation', () async {
    await expectLater(
      service.create(
        dive: seed('new-2', notes: 'Wall', number: 8),
        changedCardIds: ['notes'],
        alsoWrite: () async => throw StateError('boom'),
      ),
      throwsStateError,
    );

    expect(await dives.getDiveById('new-2'), isNull);
    expect(await operations(), isEmpty);

    // Save can be tried again, with the same id.
    await service.create(
      dive: seed('new-2', notes: 'Wall', number: 8),
      changedCardIds: ['notes'],
    );
    expect((await dives.getDiveById('new-2'))!.notes, 'Wall');
  });

  test('an unnumbered logged dive is numbered; a planned one is not', () async {
    final logged = await service.create(
      dive: seed('logged'),
      changedCardIds: ['notes'],
    );
    final planned = await service.create(
      dive: seed('planned', planned: true),
      changedCardIds: ['notes'],
    );

    expect(logged.after.diveNumber, isNotNull);
    expect((await dives.getDiveById('logged'))!.diveNumber, isNotNull);
    expect(planned.after.diveNumber, isNull);
  });

  test('a dive with a trip stretches the trip to cover it', () async {
    final trip = await trips.createTrip(
      Trip(
        id: 'trip',
        diverId: 'me',
        name: 'Trip',
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 22),
        createdAt: epoch,
        updatedAt: epoch,
      ),
    );

    await changeLog.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    final result = await service.create(
      dive: seed('new-1', number: 8).copyWith(trip: trip, tripId: 'trip'),
      changedCardIds: ['details'],
    );

    expect(result.tripDateStretches, hasLength(1));
    final start = (await trips.getTripById('trip'))!.startDate;
    expect((start.month, start.day), (11, 17));
    expect(await operations(), hasLength(1));
  });

  // A seed whose diver could not be read (review of #4672): the dive goes
  // to the diver active at Save, as addDive gives it, and only that
  // diver's log is numbered.
  test(
    'a dive with no diver takes the active one, and numbers only theirs',
    () async {
      await insertDiver(db, 'other');
      await insertDive(db, 'theirs', diverId: 'other', notes: 'Theirs');
      await db.customStatement(
        "UPDATE dives SET dive_number = 99 WHERE id = 'theirs'",
      );

      final result = await service.create(
        dive: Dive(
          id: 'new-1',
          dateTime: DateTime.utc(2026, 11, 17, 9, 30),
          entryTime: DateTime.utc(2026, 11, 17, 9, 30),
        ),
        changedCardIds: ['notes'],
        activeDiverId: 'me',
      );

      expect(result.after.diverId, 'me');
      expect(result.after.diveNumber, isNotNull);
      expect((await dives.getDiveById('theirs'))!.diveNumber, 99);
    },
  );

  test('an id already stored, or none, is refused', () async {
    await expectLater(
      service.create(dive: seed('old'), changedCardIds: ['notes']),
      throwsStateError,
    );
    await expectLater(
      service.create(dive: seed(''), changedCardIds: ['notes']),
      throwsStateError,
    );
    expect((await dives.getDiveById('old'))!.notes, 'Earlier');
  });
}
