import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

/// Putting a dive on a trip stretches the trip to cover it (issue #3351).
void main() {
  late AppDatabase db;
  late TripRepository trips;

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripRepository();
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
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'late',
            diveDateTime: DateTime.utc(2026, 3, 14, 9).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<DateTime> endDate() async => (await trips.getTripById('t'))!.endDate;

  test('assignDivesToTrip stretches', () async {
    await trips.assignDivesToTrip(['late'], 't');
    expect(await endDate(), DateTime(2026, 3, 14));
  });

  test('assignDiveToTrip stretches', () async {
    await trips.assignDiveToTrip('late', 't');
    expect(await endDate(), DateTime(2026, 3, 14));
  });

  test('bulkUpdateTrip stretches', () async {
    await DiveRepository().bulkUpdateTrip(['late'], 't');
    expect(await endDate(), DateTime(2026, 3, 14));
  });

  test('bulkUpdateTrip to no trip stretches nothing', () async {
    await db.customStatement("UPDATE dives SET trip_id = 't'");
    await DiveRepository().bulkUpdateTrip(['late'], null);
    expect(await endDate(), DateTime(2026, 3, 10));
  });

  test('stretchToCoverDives returns what it changed', () async {
    await db.customStatement("UPDATE dives SET trip_id = 't'");

    final first = await trips.stretchToCoverDives(['late']);
    final second = await trips.stretchToCoverDives(['late']);

    expect(first.single.end, DateTime(2026, 3, 14));
    expect(second, isEmpty);
  });
}
