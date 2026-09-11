import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> insertTrip(String id, String name) async {
    await db
        .into(db.trips)
        .insert(
          TripsCompanion(
            id: Value(id),
            name: Value(name),
            startDate: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
            endDate: Value(DateTime(2026, 6, 9).millisecondsSinceEpoch),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive(String id, {String? tripId, DateTime? date}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            name: Value('Dive $id'),
            diveDateTime: Value(
              asWallClockUtc(
                date ?? DateTime(2026, 6, 8),
              ).millisecondsSinceEpoch,
            ),
            tripId: Value(tripId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  group('dive summary trip fields', () {
    test('getDiveSummaries populates trip identity', () async {
      await insertTrip('t1', 'Tassie');
      await insertDive('d1', tripId: 't1');
      await insertDive('d2');

      final summaries = await repository.getDiveSummaries();
      final onTrip = summaries.firstWhere((s) => s.id == 'd1');
      final loose = summaries.firstWhere((s) => s.id == 'd2');

      expect(onTrip.tripId, 't1');
      expect(onTrip.tripName, 'Tassie');
      expect(onTrip.tripStartDate, DateTime(2026, 6, 8));
      expect(onTrip.tripEndDate, DateTime(2026, 6, 9));
      expect(loose.tripId, isNull);
      expect(loose.tripName, isNull);
      expect(loose.tripStartDate, isNull);
      expect(loose.tripEndDate, isNull);
    });

    // No test for a dangling trip_id: dives.trip_id carries a foreign key, so
    // the database refuses to store one. The LEFT JOIN is still the right
    // shape, since a dive simply has no trip most of the time.

    test('the id-batch summary path populates trip identity too', () async {
      await insertTrip('t1', 'Tassie');
      await insertDive('d1', tripId: 't1');

      final summaries = await repository.getSummariesByIds(['d1']);

      expect(summaries.single.tripId, 't1');
      expect(summaries.single.tripName, 'Tassie');
      expect(summaries.single.tripStartDate, DateTime(2026, 6, 8));
      expect(summaries.single.tripEndDate, DateTime(2026, 6, 9));
    });

    test('the join does not duplicate rows', () async {
      await insertTrip('t1', 'Tassie');
      await insertDive('d1', tripId: 't1');
      await insertDive('d2', tripId: 't1');

      final summaries = await repository.getDiveSummaries();

      expect(summaries, hasLength(2));
    });
  });
}
