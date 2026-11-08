import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/drift_statement_log.dart';
import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The trip list read for a handful of ids (issue #4247): Global Search
/// draws up to five trips and must not pay for every trip's stats.
void main() {
  late AppDatabase db;
  late TripRepository trips;

  setUp(() async {
    db = await setUpStatementLoggingTestDatabase();
    trips = TripRepository();
    await withoutStatementLog(() async {
      await seedDivers(db, ['a', 'b']);
      for (final id in const ['t1', 't2', 't3']) {
        await seedTrip(db, id, owner: 'a', shared: true);
        await seedDive(db, 'dive-$id', diver: 'a', tripId: id);
      }
      await ProfileHidesRepository().hide(SharedItemKind.trip, 't3', 'b');
    });
  });

  tearDown(tearDownTestDatabase);

  test('holds what the list holds for those trips, and no others', () async {
    final list = await withoutStatementLog(
      () => trips.getAllTripsWithStats(diverId: 'a'),
    );

    final scoped = await withoutStatementLog(
      () => trips.getAllTripsWithStats(diverId: 'a', ids: const ['t3', 't1']),
    );

    expect(scoped.toSet(), list.where((e) => e.trip.id != 't2').toSet());
    expect(scoped.first.diveCount, 1);
  });

  test('keeps a trip the diver has hidden out, as the list does', () async {
    final scoped = await withoutStatementLog(
      () => trips.getAllTripsWithStats(diverId: 'b', ids: const ['t1', 't3']),
    );

    expect([for (final e in scoped) e.trip.id], ['t1']);
  });

  test('narrows its one statement to the ids', () async {
    final sent = await statementsOf(
      () => trips.getAllTripsWithStats(ids: const ['t2']),
    );

    expect(sent.single, contains('t2'));
  });

  test('reads nothing for no ids', () async {
    final sent = await statementsOf(
      () async =>
          expect(await trips.getAllTripsWithStats(ids: const []), isEmpty),
    );

    expect(sent, isEmpty);
  });
}
