import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late TripRepository repository;
  late AppDatabase db;

  const diverId = 'diver-1';
  const tripId = 'trip-1';
  const otherTripId = 'trip-2';

  setUp(() async {
    db = await setUpTestDatabase();
    repository = TripRepository();

    // Insert a diver (FK constraint)
    await db.customInsert(
      'INSERT INTO divers (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable.withString(diverId),
        Variable.withString('Test Diver'),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );

    // Insert a second diver for cross-diver tests
    await db.customInsert(
      'INSERT INTO divers (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable.withString('diver-other'),
        Variable.withString('Other Diver'),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Insert a trip via raw SQL
  Future<void> insertTrip({
    required String id,
    required DateTime startDate,
    required DateTime endDate,
    String name = 'Test Trip',
    String? dId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customInsert(
      '''INSERT INTO trips (id, diver_id, name, start_date, end_date,
         trip_type, notes, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable.withString(id),
        Variable.withString(dId ?? diverId),
        Variable.withString(name),
        Variable.withInt(startDate.millisecondsSinceEpoch),
        Variable.withInt(endDate.millisecondsSinceEpoch),
        Variable.withString('shore'),
        Variable.withString(''),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
    );
  }

  /// Insert a dive via raw SQL
  Future<void> insertDive({
    required String id,
    required DateTime dateTime,
    required String dId,
    String? tId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customInsert(
      '''INSERT INTO dives (id, diver_id, dive_date_time, trip_id,
         dive_type, notes, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable.withString(id),
        Variable.withString(dId),
        Variable.withInt(dateTime.millisecondsSinceEpoch),
        tId != null ? Variable.withString(tId) : const Variable(null),
        Variable.withString('recreational'),
        Variable.withString(''),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
    );
  }

  group('findCandidateDivesForTrip', () {
    test('returns unassigned dives within trip date range', () async {
      final startDate = DateTime(2024, 6, 1);
      final endDate = DateTime(2024, 6, 7);

      await insertTrip(id: tripId, startDate: startDate, endDate: endDate);

      // Dive within range, unassigned
      await insertDive(
        id: 'dive-in-range',
        dateTime: DateTime(2024, 6, 3),
        dId: diverId,
      );

      // Dive outside range (before)
      await insertDive(
        id: 'dive-before',
        dateTime: DateTime(2024, 5, 20),
        dId: diverId,
      );

      // Dive outside range (after)
      await insertDive(
        id: 'dive-after',
        dateTime: DateTime(2024, 6, 15),
        dId: diverId,
      );

      final candidates = await repository.findCandidateDivesForTrip(
        tripId: tripId,
        startDate: startDate,
        endDate: endDate,
        diverId: diverId,
      );

      expect(candidates, hasLength(1));
      expect(candidates.first.dive.id, equals('dive-in-range'));
      expect(candidates.first.isUnassigned, isTrue);
      expect(candidates.first.currentTripId, isNull);
      expect(candidates.first.currentTripName, isNull);
    });

    test('excludes dives already on this trip', () async {
      final startDate = DateTime(2024, 6, 1);
      final endDate = DateTime(2024, 6, 7);

      await insertTrip(id: tripId, startDate: startDate, endDate: endDate);

      // Dive already assigned to THIS trip
      await insertDive(
        id: 'dive-already-on-trip',
        dateTime: DateTime(2024, 6, 3),
        dId: diverId,
        tId: tripId,
      );

      // Unassigned dive in range
      await insertDive(
        id: 'dive-unassigned',
        dateTime: DateTime(2024, 6, 4),
        dId: diverId,
      );

      final candidates = await repository.findCandidateDivesForTrip(
        tripId: tripId,
        startDate: startDate,
        endDate: endDate,
        diverId: diverId,
      );

      expect(candidates, hasLength(1));
      expect(candidates.first.dive.id, equals('dive-unassigned'));
    });

    test('includes dives on other trips with trip name', () async {
      final startDate = DateTime(2024, 6, 1);
      final endDate = DateTime(2024, 6, 7);

      await insertTrip(id: tripId, startDate: startDate, endDate: endDate);
      await insertTrip(
        id: otherTripId,
        startDate: DateTime(2024, 5, 1),
        endDate: DateTime(2024, 6, 15),
        name: 'Other Trip',
      );

      // Dive assigned to another trip but in this trip's range
      await insertDive(
        id: 'dive-other-trip',
        dateTime: DateTime(2024, 6, 2),
        dId: diverId,
        tId: otherTripId,
      );

      final candidates = await repository.findCandidateDivesForTrip(
        tripId: tripId,
        startDate: startDate,
        endDate: endDate,
        diverId: diverId,
      );

      expect(candidates, hasLength(1));
      expect(candidates.first.dive.id, equals('dive-other-trip'));
      expect(candidates.first.currentTripId, equals(otherTripId));
      expect(candidates.first.currentTripName, equals('Other Trip'));
      expect(candidates.first.isUnassigned, isFalse);
    });

    test('excludes dives from other divers', () async {
      final startDate = DateTime(2024, 6, 1);
      final endDate = DateTime(2024, 6, 7);

      await insertTrip(id: tripId, startDate: startDate, endDate: endDate);

      // Dive from a different diver
      await insertDive(
        id: 'dive-other-diver',
        dateTime: DateTime(2024, 6, 3),
        dId: 'diver-other',
      );

      // Dive from the correct diver
      await insertDive(
        id: 'dive-correct-diver',
        dateTime: DateTime(2024, 6, 4),
        dId: diverId,
      );

      final candidates = await repository.findCandidateDivesForTrip(
        tripId: tripId,
        startDate: startDate,
        endDate: endDate,
        diverId: diverId,
      );

      expect(candidates, hasLength(1));
      expect(candidates.first.dive.id, equals('dive-correct-diver'));
    });
  });

  group('assignDivesToTrip (batch)', () {
    test('batch assigns multiple dives to a trip', () async {
      final startDate = DateTime(2024, 6, 1);
      final endDate = DateTime(2024, 6, 7);

      await insertTrip(id: tripId, startDate: startDate, endDate: endDate);

      await insertDive(
        id: 'dive-a',
        dateTime: DateTime(2024, 6, 2),
        dId: diverId,
      );
      await insertDive(
        id: 'dive-b',
        dateTime: DateTime(2024, 6, 3),
        dId: diverId,
      );
      await insertDive(
        id: 'dive-c',
        dateTime: DateTime(2024, 6, 4),
        dId: diverId,
      );

      await repository.assignDivesToTrip([
        'dive-a',
        'dive-b',
        'dive-c',
      ], tripId);

      // Verify via raw SQL
      final rows = await db
          .customSelect(
            'SELECT id, trip_id FROM dives WHERE trip_id = ? ORDER BY id',
            variables: [Variable.withString(tripId)],
          )
          .get();

      expect(rows, hasLength(3));
      final ids = rows.map((r) => r.data['id'] as String).toList();
      expect(ids, containsAll(['dive-a', 'dive-b', 'dive-c']));
    });

    test('handles empty list gracefully', () async {
      // Should not throw
      await repository.assignDivesToTrip([], tripId);
    });
  });
}
