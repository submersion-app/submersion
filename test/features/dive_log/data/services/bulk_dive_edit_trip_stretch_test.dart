import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

/// The bulk edit Trip row stretches the trip to cover the dives, and Undo puts
/// its dates back (issue #3351).
void main() {
  late AppDatabase db;
  late BulkDiveEditService service;

  setUp(() async {
    db = await setUpTestDatabase();
    service = BulkDiveEditService(
      DiveRepository(),
      BuddyRepository(),
      SpeciesRepository(),
    );
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't',
            name: 'Roatan',
            startDate: DateTime(2026, 3, 5).millisecondsSinceEpoch,
            endDate: DateTime(2026, 3, 10).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final (id, at) in [
      ('early', DateTime.utc(2026, 3, 1, 9)),
      ('inside', DateTime.utc(2026, 3, 7, 9)),
      ('late', DateTime.utc(2026, 3, 14, 9)),
    ]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: at.millisecondsSinceEpoch,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
  });
  tearDown(() async => tearDownTestDatabase());

  BulkEditRequest setTrip(List<String> ids, String? tripId) => BulkEditRequest(
    diveIds: ids,
    scalars: DivesCompanion(tripId: Value(tripId)),
  );

  Future<(DateTime, DateTime)> tripDates() async {
    final row = await (db.select(
      db.trips,
    )..where((t) => t.id.equals('t'))).getSingle();
    return (
      DateTime.fromMillisecondsSinceEpoch(row.startDate),
      DateTime.fromMillisecondsSinceEpoch(row.endDate),
    );
  }

  test('a trip that must stretch does, and the snapshot says so', () async {
    final snapshot = await service.apply(setTrip(['early', 'late'], 't'));

    expect(await tripDates(), (DateTime(2026, 3, 1), DateTime(2026, 3, 14)));
    expect(snapshot.tripDateStretches.single.tripId, 't');
    expect(snapshot.tripDateStretches.single.tripName, 'Roatan');
  });

  test('a trip that covers the dives reports nothing', () async {
    final snapshot = await service.apply(setTrip(['inside'], 't'));

    expect(snapshot.tripDateStretches, isEmpty);
    expect(await tripDates(), (DateTime(2026, 3, 5), DateTime(2026, 3, 10)));
  });

  test('clearing the trip stretches nothing', () async {
    await db.customStatement("UPDATE dives SET trip_id = 't'");

    final snapshot = await service.apply(setTrip(['late'], null));

    expect(snapshot.tripDateStretches, isEmpty);
    expect(await tripDates(), (DateTime(2026, 3, 5), DateTime(2026, 3, 10)));
  });

  test('an edit with no trip field leaves a trip alone', () async {
    await db.customStatement("UPDATE dives SET trip_id = 't'");

    final snapshot = await service.apply(
      const BulkEditRequest(
        diveIds: ['late'],
        scalars: DivesCompanion(rating: Value(4)),
      ),
    );

    expect(snapshot.tripDateStretches, isEmpty);
    expect(await tripDates(), (DateTime(2026, 3, 5), DateTime(2026, 3, 10)));
  });

  test('undo restores the trip with the dives', () async {
    final snapshot = await service.apply(setTrip(['early', 'late'], 't'));

    await service.undo(snapshot);

    expect(await tripDates(), (DateTime(2026, 3, 5), DateTime(2026, 3, 10)));
    final row = await (db.select(
      db.dives,
    )..where((d) => d.id.equals('late'))).getSingle();
    expect(row.tripId, isNull);
  });

  test('undo leaves a bound edited since', () async {
    final snapshot = await service.apply(setTrip(['early', 'late'], 't'));
    await (db.update(db.trips)..where((t) => t.id.equals('t'))).write(
      TripsCompanion(
        endDate: Value(DateTime(2026, 3, 20).millisecondsSinceEpoch),
      ),
    );

    await service.undo(snapshot);

    expect(await tripDates(), (DateTime(2026, 3, 5), DateTime(2026, 3, 20)));
  });
}
