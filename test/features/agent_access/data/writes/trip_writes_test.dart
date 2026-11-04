import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Trips, as the trip edit page keeps them: a name and a range of days, a
/// side trip one level deep, sharing for the owner only, and the dives the
/// diver assigns, which stretch the trip to cover them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Map<String, Object?> trip(Map<String, Object?> more) => {
    'name': 'Red Sea',
    'trip_type': 'shore',
    'start_date': '2024-03-10',
    'end_date': '2024-03-12',
    ...more,
  };

  Future<String> created(Map<String, Object?> fields) async =>
      (await h.run([createOp('trips', trip(fields))])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a trip is created, edited and deleted with its reach', () async {
    final id = await created({'notes': ' Wrecks '});
    final doc = (await h.one('trips', id))!;
    expect(doc['start_date'], '2024-03-10');
    expect(doc['end_date'], '2024-03-12');
    expect(doc['diver_id'], kDiverA);
    expect(doc['divers_sharing_cylinders'], 1);

    await h.run([
      updateOp('trips', id, {'name': 'Egypt'}),
    ]);
    expect((await h.one('trips', id))!['name'], 'Egypt');

    final plan = await h.preview([deleteOp('trips', id)]);
    expect(plan.items.single.block, isNull);
    await h.apply(plan);
    expect(await h.one('trips', id), isNull);
  });

  test('an end before the start is refused', () async {
    final plan = await h.preview([
      createOp('trips', trip({'end_date': '2024-03-01'})),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  // A side trip hangs off a trip of its own, one level deep.
  test('a side trip cannot have side trips', () async {
    final parent = await created({});
    final side = await created({'parent_trip_id': parent});

    final plan = await h.preview([
      createOp('trips', trip({'parent_trip_id': side})),
      updateOp('trips', parent, {'parent_trip_id': side}),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  test('assigning a dive stretches the trip, listed', () async {
    final id = await created({
      'start_date': '2024-03-15',
      'end_date': '2024-03-16',
    });

    final plan = await h.preview([
      {
        'op': 'update',
        'entity': 'trips',
        'id': id,
        'relations': {
          'dive_ids': {
            'add': ['d1'],
          },
        },
      },
    ]);
    expect(plan.items.single.alsoChanges['trips'], 1);
    await h.apply(plan);

    expect((await h.one('trips', id))!['start_date'], '2024-03-14');
  });

  test('a new liveaboard trip lists the days it generates', () async {
    final plan = await h.preview([
      createOp('trips', trip({'trip_type': 'liveaboard'})),
    ]);
    expect(plan.items.single.alsoCreates, {'itinerary_days': 3});
    await h.apply(plan);

    expect(await db.select(db.tripItineraryDays).get(), hasLength(3));
  });

  test('the return flight round-trips as a wall clock', () async {
    final id = await created({'return_flight_time': '2024-03-12T18:45:00Z'});
    final doc = (await h.one('trips', id))!;
    expect(doc['return_flight_time'], '2024-03-12T18:45:00.000Z');

    final again = await h.preview([
      updateOp('trips', id, {'return_flight_time': doc['return_flight_time']}),
    ]);
    expect(again.unchanged.single.id, id);
  });
}
