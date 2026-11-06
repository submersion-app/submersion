import 'package:drift/drift.dart' show Value;
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

  // deleteTrip deletes the slots, checklists and days by hand (their keys
  // have no action), and with them the fills, checklist rows and the slot
  // link on every tank that used one.
  test('a trip delete lists what its children take with them', () async {
    final id = await created({});
    Future<String> make(String entity, Map<String, Object?> values) async =>
        (await h.run([createOp(entity, values)])).created.single.id;
    final slot = await make('trip_cylinders', {'trip_id': id, 'label': 'AL80'});
    await make('trip_cylinder_events', {
      'trip_cylinder_id': slot,
      'kind': 'fill',
      'pressure_bar': 200.0,
    });
    final list = await make('trip_checklists', {'trip_id': id, 'name': 'Gear'});
    await make('trip_checklist_items', {'checklist_id': list, 'title': 'Mask'});
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank-1',
            diveId: 'd1',
            tripCylinderId: Value(slot),
          ),
        );
    Future<int> rows(String table) async =>
        (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
            .read<int>('n');

    final sections = await rows('trip_checklist_sections');

    final reach = (await h.preview([deleteOp('trips', id)])).items.single.reach;

    expect(reach.parts, {
      'trip_cylinders': 1,
      'trip_cylinder_events': 1,
      'trip_checklists': 1,
      if (sections > 0) 'trip_checklist_sections': sections,
      'trip_checklist_items': 1,
    });
    expect(reach.unlinked, {'dive_tanks': 1});
  });

  // An agent sees every profile and writes a record as its owner, so the
  // trip page's owner-only gates (sharing, delete) pass for the owner.
  test('another profile\'s trip and its parts are written as that '
      'profile', () async {
    final id = (await h.run([
      createOp('trips', trip({}), diver: kDiverB),
    ])).created.single.id;

    await h.run([
      updateOp('trips', id, {'name': 'Egypt', 'is_shared': true}),
      createOp('trip_cylinders', {'trip_id': id, 'label': 'AL80'}),
      createOp('trip_checklists', {'trip_id': id, 'name': 'Gear'}),
    ]);
    final doc = (await h.one('trips', id))!;
    expect(
      [doc['name'], doc['is_shared'], doc['diver_id']],
      ['Egypt', true, kDiverB],
    );
    expect(await db.select(db.tripCylinders).get(), hasLength(1));

    final plan = await h.preview([deleteOp('trips', id)]);
    expect(plan.items.single.block, isNull);
    await h.apply(plan);
    expect(await h.one('trips', id), isNull);
    expect(await db.select(db.tripCylinders).get(), isEmpty);
  });

  // bulkUpdateFields drops a tank's link into the old trip's slots when the
  // dive moves, as assigning it from the trip side does.
  test('moving a dive to another trip lists the slot links it drops', () async {
    final from = await created({});
    final to = await created({'name': 'Second'});
    final slot = (await h.run([
      createOp('trip_cylinders', {'trip_id': from, 'label': 'AL80'}),
    ])).created.single.id;
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank-1',
            diveId: 'd1',
            tripCylinderId: Value(slot),
          ),
        );
    Map<String, Object?> toTrip(String trip) => {
      ...updateOp('dives', 'd1', {}),
      'relations': {
        'trip': {
          'set': [trip],
        },
      },
    };
    await h.run([toTrip(from)]);

    final plan = await h.preview([toTrip(to)]);

    expect(plan.items.single.alsoChanges['dive_tanks'], 1);
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

  // stretchTripsToCoverDives moves a larger trip only when its side trip
  // moves: a side trip may sit past the larger trip's end on purpose.
  test('a side trip that covers the dive stretches nothing', () async {
    final parent = await created({});
    final side = await created({
      'name': 'Side',
      'start_date': '2024-03-14',
      'end_date': '2024-03-16',
      'parent_trip_id': parent,
    });

    final fromTrip = await h.preview([
      {
        ...updateOp('trips', side, {}),
        'relations': {
          'dive_ids': {
            'add': ['d1'],
          },
        },
      },
    ]);
    final fromDive = await h.preview([
      {
        ...updateOp('dives', 'd1', {}),
        'relations': {
          'trip': {
            'set': [side],
          },
        },
      },
    ]);

    expect(fromTrip.items.single.alsoChanges['trips'], isNull);
    expect(fromDive.items.single.alsoChanges['trips'], isNull);
    await h.apply(fromTrip);
    expect((await h.one('trips', parent))!['end_date'], '2024-03-12');
  });

  test('a new liveaboard trip lists the days it generates', () async {
    final plan = await h.preview([
      createOp('trips', trip({'trip_type': 'liveaboard'})),
    ]);
    expect(plan.items.single.alsoCreates, {'trip_itinerary_days': 3});
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
