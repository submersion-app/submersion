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

  Future<void> insertTrip(String id) async {
    await db
        .into(db.trips)
        .insert(
          TripsCompanion(
            id: Value(id),
            name: Value('Trip $id'),
            startDate: Value(now),
            endDate: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive(String id, {String? tripId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(
              asWallClockUtc(DateTime(2026, 6, 8)).millisecondsSinceEpoch,
            ),
            tripId: Value(tripId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  group('getTripDiveCounts', () {
    test('counts dives per trip and omits loose dives', () async {
      await insertTrip('t1');
      await insertTrip('t2');
      await insertDive('d1', tripId: 't1');
      await insertDive('d2', tripId: 't1');
      await insertDive('d3', tripId: 't2');
      await insertDive('d4');

      final counts = await repository.getTripDiveCounts();

      expect(counts['t1'], 2);
      expect(counts['t2'], 1);
      expect(counts.length, 2);
    });

    test('returns an empty map when nothing is on a trip', () async {
      await insertDive('d1');

      expect(await repository.getTripDiveCounts(), isEmpty);
    });

    test('a trip with no dives is absent rather than zero', () async {
      await insertTrip('t1');

      expect(await repository.getTripDiveCounts(), isEmpty);
    });
  });
}
