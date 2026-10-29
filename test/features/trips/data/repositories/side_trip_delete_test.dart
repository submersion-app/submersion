import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

/// Deleting a side trip returns its dives to the larger trip; deleting a
/// larger trip leaves its side trips as trips of their own (issue #3658).
void main() {
  late AppDatabase db;
  late TripRepository trips;

  Future<void> diver(String id) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion(
            id: Value('settings-$id'),
            diverId: Value(id),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
  }

  Future<void> trip(String id, {String? parent, String? owner}) =>
      db.customStatement(
        'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
        'parent_trip_id, created_at, updated_at) '
        'VALUES (?, ?, ?, 0, 0, ?, 0, 0)',
        [id, owner, id, parent],
      );

  Future<void> dive(String id, String tripId, {String? owner}) =>
      db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, trip_id, '
        'created_at, updated_at) VALUES (?, ?, 0, ?, 0, 0)',
        [id, owner, tripId],
      );

  Future<String?> tripOf(String diveId) async =>
      (await db
              .customSelect(
                'SELECT trip_id FROM dives WHERE id = ?',
                variables: [Variable<String>(diveId)],
              )
              .getSingle())
          .readNullable<String>('trip_id');

  Future<String?> parentOf(String tripId) async =>
      (await db
              .customSelect(
                'SELECT parent_trip_id FROM trips WHERE id = ?',
                variables: [Variable<String>(tripId)],
              )
              .getSingle())
          .readNullable<String>('parent_trip_id');

  Future<bool> pending(String entityType, String recordId) async =>
      (await db
              .customSelect(
                "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? "
                "AND record_id = ? AND sync_status = 'pending'",
                variables: [
                  Variable<String>(entityType),
                  Variable<String>(recordId),
                ],
              )
              .getSingle())
          .read<int>('n') >
      0;

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripRepository();
  });
  tearDown(tearDownTestDatabase);

  test("deleting a side trip hands every profile's dives back", () async {
    await diver('a');
    await diver('b');
    await trip('P', owner: 'a');
    await trip('S', parent: 'P', owner: 'a');
    await dive('d1', 'S', owner: 'a');
    await dive('d2', 'S', owner: 'b');
    expect(await trips.deleteTrip('S'), isTrue);
    expect(await tripOf('d1'), 'P');
    expect(await tripOf('d2'), 'P');
    expect(await pending('dives', 'd2'), isTrue);
  });

  test('deleting a larger trip leaves its side trip standalone', () async {
    await trip('P');
    await trip('S', parent: 'P');
    await dive('p1', 'P');
    await dive('s1', 'S');
    expect(await trips.deleteTrip('P'), isTrue);
    expect(await parentOf('S'), isNull);
    expect(await pending('trips', 'S'), isTrue);
    expect(await tripOf('s1'), 'S');
    expect(await tripOf('p1'), isNull);
  });

  test("a profile delete returns survivors' dives to the parent", () async {
    await diver('keep');
    await diver('gone');
    await trip('P', owner: 'keep');
    await trip('S', parent: 'P', owner: 'gone');
    await dive('k1', 'S', owner: 'keep');
    await DiverRepository().deleteDiver('gone');
    expect(await tripOf('k1'), 'P');
  });

  test("a profile delete frees a survivor's side trip", () async {
    await diver('keep');
    await diver('gone');
    await trip('P', owner: 'gone');
    await trip('S', parent: 'P', owner: 'keep');
    await dive('k1', 'S', owner: 'keep');
    await DiverRepository().deleteDiver('gone');
    expect(await parentOf('S'), isNull);
    expect(await tripOf('k1'), 'S');
  });
}
