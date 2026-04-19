import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiverRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> insertDiver(
    String id, {
    String name = 'Test Diver',
    bool isDefault = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(name),
            isDefault: Value(isDefault),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDiverSettings(String diverId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion(
            id: Value('settings-$diverId'),
            diverId: Value(diverId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<String> insertTrip(
    String id, {
    required String diverId,
    String name = 'Test Trip',
    bool isShared = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: id,
            diverId: Value(diverId),
            name: name,
            startDate: now,
            endDate: now,
            isShared: Value(isShared),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<String> insertSite(
    String id, {
    required String diverId,
    String name = 'Test Site',
    bool isShared = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            diverId: Value(diverId),
            name: name,
            isShared: Value(isShared),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<List<Trip>> getTrips() => db.select(db.trips).get();

  Future<List<DiveSite>> getSites() => db.select(db.diveSites).get();

  // ---------------------------------------------------------------------------
  // deleteDiverWithReassignment — two-diver scenario
  // ---------------------------------------------------------------------------

  group('deleteDiverWithReassignment — two divers', () {
    test(
      'reassigns shared trip/site to surviving diver, deletes private records',
      () async {
        // Seed: diver A (owner) + diver B (survivor).
        await insertDiver('diver-a', name: 'Alice');
        await insertDiver('diver-b', name: 'Bob');
        await insertDiverSettings('diver-a');
        await insertDiverSettings('diver-b');

        // A owns 3 trips: 1 shared, 2 private.
        await insertTrip('trip-shared', diverId: 'diver-a', isShared: true);
        await insertTrip('trip-private-1', diverId: 'diver-a', isShared: false);
        await insertTrip('trip-private-2', diverId: 'diver-a', isShared: false);

        // A owns 2 sites: 1 shared, 1 private.
        await insertSite('site-shared', diverId: 'diver-a', isShared: true);
        await insertSite('site-private', diverId: 'diver-a', isShared: false);

        // Delete A.
        final result = await repository.deleteDiverWithReassignment('diver-a');

        // Counts in result are correct.
        expect(result.reassignedTripsCount, equals(1));
        expect(result.reassignedSitesCount, equals(1));
        expect(result.reassignedToDiverId, equals('diver-b'));
        expect(result.reassignedToDiverName, equals('Bob'));
        expect(result.hasReassignments, isTrue);

        // Shared trip now belongs to diver B.
        final trips = await getTrips();
        expect(
          trips.where((t) => t.id == 'trip-shared').single.diverId,
          equals('diver-b'),
        );

        // Private trips are gone.
        expect(
          trips.map((t) => t.id).toList(),
          isNot(contains('trip-private-1')),
        );
        expect(
          trips.map((t) => t.id).toList(),
          isNot(contains('trip-private-2')),
        );

        // Shared site now belongs to diver B.
        final sites = await getSites();
        expect(
          sites.where((s) => s.id == 'site-shared').single.diverId,
          equals('diver-b'),
        );

        // Private site is gone.
        expect(
          sites.map((s) => s.id).toList(),
          isNot(contains('site-private')),
        );
      },
    );

    test(
      'prefers default diver over first-by-createdAt as reassignment target',
      () async {
        // B was created first but C is the default.
        await insertDiver('diver-a', name: 'Alice');
        await insertDiver('diver-b', name: 'Bob');
        await insertDiver('diver-c', name: 'Carol', isDefault: true);
        await insertDiverSettings('diver-a');
        await insertDiverSettings('diver-b');
        await insertDiverSettings('diver-c');

        await insertTrip('trip-shared', diverId: 'diver-a', isShared: true);

        final result = await repository.deleteDiverWithReassignment('diver-a');

        expect(result.reassignedToDiverId, equals('diver-c'));
        final trip = (await getTrips()).single;
        expect(trip.diverId, equals('diver-c'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // deleteDiverWithReassignment — single-diver scenario (no survivors)
  // ---------------------------------------------------------------------------

  group('deleteDiverWithReassignment — no surviving diver', () {
    test(
      'falls back to deleting all records when no survivors exist',
      () async {
        // Only diver A — shared and private records alike.
        await insertDiver('diver-a', name: 'Alice');
        await insertDiverSettings('diver-a');

        await insertTrip('trip-shared', diverId: 'diver-a', isShared: true);
        await insertTrip('trip-private', diverId: 'diver-a', isShared: false);
        await insertSite('site-shared', diverId: 'diver-a', isShared: true);
        await insertSite('site-private', diverId: 'diver-a', isShared: false);

        final result = await repository.deleteDiverWithReassignment('diver-a');

        // No reassignment occurred.
        expect(result.reassignedTripsCount, equals(0));
        expect(result.reassignedSitesCount, equals(0));
        expect(result.reassignedToDiverId, isNull);
        expect(result.reassignedToDiverName, isNull);
        expect(result.hasReassignments, isFalse);

        // All records deleted.
        final trips = await getTrips();
        expect(trips, isEmpty);
        final sites = await getSites();
        expect(sites, isEmpty);
      },
    );
  });
}
