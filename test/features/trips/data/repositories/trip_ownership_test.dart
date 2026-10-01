import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Only a shared trip's owner destroys or re-shares it (issue #2594).
void main() {
  late AppDatabase db;
  late TripRepository trips;

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripRepository();
    await seedDivers(db, ['a', 'b']);
    await seedTrip(db, 'shared', owner: 'a', shared: true);
    await seedDive(db, 'a1', diver: 'a', tripId: 'shared');
    await seedDive(db, 'b1', diver: 'b', tripId: 'shared');
  });

  tearDown(tearDownTestDatabase);

  Future<String?> tripOf(String diveId) async => (await (db.select(
    db.dives,
  )..where((d) => d.id.equals(diveId))).getSingle()).tripId;

  test('a non-owner cannot delete it; nothing changes', () async {
    expect(await trips.deleteTrip('shared', actingDiverId: 'b'), isFalse);
    expect(await trips.getTripById('shared'), isNotNull);
    expect(await tripOf('a1'), 'shared');
    expect(await tripOf('b1'), 'shared');
  });

  test(
    'the owner deletes it; every dive is unlinked, stamped and pending',
    () async {
      await clearPendingMarks(db);
      expect(await trips.deleteTrip('shared', actingDiverId: 'a'), isTrue);
      expect(await trips.getTripById('shared'), isNull);
      for (final dive in ['a1', 'b1']) {
        expect(await tripOf(dive), isNull);
        expect(await pendingCount(db, 'dives', dive), 1, reason: dive);
      }
    },
  );

  test('the owner\'s delete tombstones every profile\'s hide', () async {
    await ProfileHidesRepository().hide(SharedItemKind.trip, 'shared', 'b');
    await trips.deleteTrip('shared', actingDiverId: 'a');
    expect(await db.select(db.tripHides).get(), isEmpty);
    expect(await tombstoneCount(db, ProfileHidesRepository.tripEntity), 1);
  });

  test('an ownerless trip is deleted by anyone', () async {
    await seedTrip(db, 'legacy', shared: true);
    expect(await trips.deleteTrip('legacy', actingDiverId: 'b'), isTrue);
  });

  test('a caller naming no profile deletes as before', () async {
    expect(await trips.deleteTrip('shared'), isTrue);
  });

  test('a trip already gone counts as deleted, not as refused', () async {
    // Another device deleted it and sync removed the row meanwhile: the
    // page must not tell its owner they do not own it.
    expect(await trips.deleteTrip('nope', actingDiverId: 'a'), isTrue);
  });

  test('a non-owner\'s save cannot unshare it but still edits it', () async {
    final trip = (await trips.getTripById('shared'))!;
    await trips.updateTrip(
      trip.copyWith(name: 'Renamed', isShared: false),
      actingDiverId: 'b',
    );
    final saved = (await trips.getTripById('shared'))!;
    expect(saved.name, 'Renamed');
    expect(saved.isShared, isTrue);
    expect(saved.diverId, 'a');
  });

  test('the owner\'s save unshares it', () async {
    final trip = (await trips.getTripById('shared'))!;
    await trips.updateTrip(trip.copyWith(isShared: false), actingDiverId: 'a');
    expect((await trips.getTripById('shared'))!.isShared, isFalse);
  });

  test('setShared refuses a non-owner', () async {
    expect(await trips.setShared('shared', false, actingDiverId: 'b'), isFalse);
    expect((await trips.getTripById('shared'))!.isShared, isTrue);
  });
}
