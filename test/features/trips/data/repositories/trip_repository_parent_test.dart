import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

/// The larger trip a side trip is part of (issue #3658) is stored, read back
/// by every mapper, and cleared on demand.
void main() {
  late AppDatabase db;
  late TripRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = TripRepository();
  });
  tearDown(tearDownTestDatabase);

  Trip trip(String name, {String? parentTripId}) {
    final now = DateTime(2026, 3, 1);
    return Trip(
      id: '',
      name: name,
      startDate: DateTime(2026, 3, 2),
      endDate: DateTime(2026, 3, 16),
      parentTripId: parentTripId,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('Trip.copyWith keeps, sets and clears the parent', () {
    final side = trip('Raja Ampat', parentTripId: 'p1');
    expect(side.copyWith(name: 'x').parentTripId, 'p1');
    expect(side.copyWith(parentTripId: 'p2').parentTripId, 'p2');
    expect(side.copyWith(parentTripId: null).parentTripId, isNull);
    expect(side, isNot(side.copyWith(parentTripId: 'p2')));
  });

  test('createTrip stores the parent and getTripById reads it', () async {
    final parent = await repository.createTrip(trip('Indonesia'));
    final side = await repository.createTrip(
      trip('Raja Ampat', parentTripId: parent.id),
    );
    final read = await repository.getTripById(side.id);
    expect(read!.parentTripId, parent.id);
  });

  test('updateTrip clears the parent', () async {
    final parent = await repository.createTrip(trip('Indonesia'));
    final side = await repository.createTrip(
      trip('Raja Ampat', parentTripId: parent.id),
    );
    await repository.updateTrip(side.copyWith(parentTripId: null));
    expect((await repository.getTripById(side.id))!.parentTripId, isNull);
  });

  test('the stats list and search map the parent', () async {
    final parent = await repository.createTrip(trip('Indonesia'));
    final side = await repository.createTrip(
      trip('Raja Ampat', parentTripId: parent.id),
    );
    final all = await repository.getAllTripsWithStats();
    expect(
      all.singleWhere((t) => t.trip.id == side.id).trip.parentTripId,
      parent.id,
    );
    final found = await repository.searchTrips('Raja');
    expect(found.single.parentTripId, parent.id);
  });

  group('an invalid link is never written', () {
    test('a side trip cannot be a parent', () async {
      final p = await repository.createTrip(trip('Indonesia'));
      final s = await repository.createTrip(
        trip('Raja Ampat', parentTripId: p.id),
      );
      final nested = await repository.createTrip(
        trip('Day boat', parentTripId: s.id),
      );
      expect((await repository.getTripById(nested.id))!.parentTripId, isNull);
    });

    test('a missing trip cannot be a parent', () async {
      final t = await repository.createTrip(trip('Lost', parentTripId: 'gone'));
      expect((await repository.getTripById(t.id))!.parentTripId, isNull);
    });

    test('a trip with side trips cannot become one', () async {
      final p = await repository.createTrip(trip('Indonesia'));
      await repository.createTrip(trip('Raja Ampat', parentTripId: p.id));
      final q = await repository.createTrip(trip('Asia'));
      await repository.updateTrip(p.copyWith(parentTripId: q.id));
      expect((await repository.getTripById(p.id))!.parentTripId, isNull);
    });

    test('a trip cannot be its own parent', () async {
      final t = await repository.createTrip(trip('Loop'));
      await repository.updateTrip(t.copyWith(parentTripId: t.id));
      expect((await repository.getTripById(t.id))!.parentTripId, isNull);
    });
  });

  // parent_trip_id has no foreign key, because a sync can deliver a side
  // trip before its larger trip. An edit that leaves the parent alone keeps
  // it, whatever state the parent is in on this device (issue #4941).
  group('an edit that keeps the parent keeps it', () {
    Future<void> setParent(String id, String parentId) => db.customStatement(
      'UPDATE trips SET parent_trip_id = ? WHERE id = ?',
      [parentId, id],
    );

    test('when the larger trip is not on this device yet', () async {
      final side = await repository.createTrip(trip('Raja Ampat'));
      await setParent(side.id, 'not-synced-yet');
      final stored = (await repository.getTripById(side.id))!;

      await repository.updateTrip(stored.copyWith(notes: 'Mantas'));

      final after = (await repository.getTripById(side.id))!;
      expect(after.notes, 'Mantas');
      expect(after.parentTripId, 'not-synced-yet');
    });

    test('when a sync race left the larger trip a side trip', () async {
      final asia = await repository.createTrip(trip('Asia'));
      final p = await repository.createTrip(trip('Indonesia'));
      final side = await repository.createTrip(
        trip('Raja Ampat', parentTripId: p.id),
      );
      await setParent(p.id, asia.id);
      final stored = (await repository.getTripById(side.id))!;

      await repository.updateTrip(stored.copyWith(name: 'Raja'));

      expect((await repository.getTripById(side.id))!.parentTripId, p.id);
    });

    test('when a sync race gave this side trip side trips', () async {
      final p = await repository.createTrip(trip('Indonesia'));
      final side = await repository.createTrip(
        trip('Raja Ampat', parentTripId: p.id),
      );
      final day = await repository.createTrip(trip('Day boat'));
      await setParent(day.id, side.id);
      final stored = (await repository.getTripById(side.id))!;

      await repository.updateTrip(stored.copyWith(name: 'Raja'));

      expect((await repository.getTripById(side.id))!.parentTripId, p.id);
    });

    test('but a changed parent is still checked', () async {
      final side = await repository.createTrip(trip('Raja Ampat'));
      await setParent(side.id, 'not-synced-yet');
      final stored = (await repository.getTripById(side.id))!;

      await repository.updateTrip(stored.copyWith(parentTripId: 'gone'));

      expect((await repository.getTripById(side.id))!.parentTripId, isNull);
    });
  });

  test('two saves racing to link each other leave one level', () async {
    final a = await repository.createTrip(trip('A'));
    final b = await repository.createTrip(trip('B'));
    await Future.wait([
      repository.updateTrip(a.copyWith(parentTripId: b.id)),
      repository.updateTrip(b.copyWith(parentTripId: a.id)),
    ]);
    final linked = [
      (await repository.getTripById(a.id))!.parentTripId,
      (await repository.getTripById(b.id))!.parentTripId,
    ].whereType<String>();
    expect(linked, hasLength(1));
  });
}
