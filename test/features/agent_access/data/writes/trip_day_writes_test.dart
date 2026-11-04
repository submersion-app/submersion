import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// A liveaboard's vessel and a trip's itinerary days, as the trip edit page
/// and the day sheet keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> trip(String type) async => (await h.run([
    createOp('trips', {
      'name': 'Trip',
      'trip_type': type,
      'start_date': '2024-03-10',
      'end_date': '2024-03-12',
    }),
  ])).created.single.id;

  Future<List<Map<String, Object?>>> days(String tripId) async => [
    for (final id in await h.records.list('itinerary_days', parentId: tripId))
      (await h.one('itinerary_days', id))!,
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a liveaboard\'s vessel is written and edited', () async {
    final id = await trip('liveaboard');
    final details = (await h.run([
      createOp('liveaboard_details', {
        'trip_id': id,
        'vessel_name': ' Blue Horizon ',
        'vessel_type': 'motorYacht',
        'capacity': 24,
      }),
    ])).created.single.id;
    expect(
      (await h.one('liveaboard_details', details))!['vessel_name'],
      'Blue Horizon',
    );

    await h.run([
      updateOp('liveaboard_details', details, {'cabin_type': 'Twin'}),
    ]);
    expect((await h.one('liveaboard_details', details))!['cabin_type'], 'Twin');
  });

  // updateTrip deletes the vessel when the trip stops being a liveaboard,
  // and the generated days outside a shorter range: deletes, not rewrites.
  test(
    'a trip that stops being a liveaboard lists the rows it deletes',
    () async {
      final id = await trip('liveaboard');
      await h.run([
        createOp('liveaboard_details', {'trip_id': id, 'vessel_name': 'A'}),
      ]);

      final plan = await h.preview([
        updateOp('trips', id, {'trip_type': 'shore', 'end_date': '2024-03-10'}),
      ]);
      final item = plan.items.single;

      expect(item.reach.parts, {
        'liveaboard_detail_records': 1,
        'trip_itinerary_days': 1,
      });
      expect(item.alsoChanges, isEmpty);
    },
  );

  test(
    'a vessel on a shore trip, a second vessel, or a bad type is refused',
    () async {
      final shore = await trip('shore');
      final boat = await trip('liveaboard');
      await h.run([
        createOp('liveaboard_details', {'trip_id': boat, 'vessel_name': 'A'}),
      ]);

      final plan = await h.preview([
        createOp('liveaboard_details', {'trip_id': shore, 'vessel_name': 'B'}),
        createOp('liveaboard_details', {'trip_id': boat, 'vessel_name': 'C'}),
        createOp('liveaboard_details', {
          'trip_id': boat,
          'vessel_name': 'D',
          'vessel_type': 'submarine',
        }),
      ]);

      expect(plan.items[0].block!.reason, BlockReason.invalidValue);
      expect(plan.items[1].block!.reason, BlockReason.duplicateRecord);
      expect(plan.items[2].block, isNotNull);
    },
  );

  test('a day is edited and rest forces no dives, listed', () async {
    final id = await trip('liveaboard');
    final first = (await days(id)).first;

    await h.run([
      updateOp('itinerary_days', first['id']! as String, {
        'day_type': 'seaDay',
        'port_name': 'Hurghada',
        'planned_dives': 3,
      }),
    ]);
    final plan = await h.preview([
      updateOp('itinerary_days', first['id']! as String, {'day_type': 'rest'}),
    ]);
    final planned = plan.items.single.fields['planned_dives']!;
    expect([planned.newValue, planned.indirect], [0, true]);
  });

  test('a liveaboard-only day type on a shore trip is refused', () async {
    final id = await trip('shore');
    final day = (await h.run([
      createOp('itinerary_days', {'trip_id': id, 'day_date': '2024-03-10'}),
    ])).created.single.id;

    final plan = await h.preview([
      updateOp('itinerary_days', day, {'day_type': 'seaDay'}),
      updateOp('itinerary_days', day, {'planned_dives': 13}),
    ]);

    for (final item in plan.items) {
      expect(item.block, isNotNull);
    }
  });

  test('a day is added for a trip date with none, once', () async {
    final id = await trip('shore');

    final plan = await h.preview([
      createOp('itinerary_days', {'trip_id': id, 'day_date': '2024-03-11'}),
      createOp('itinerary_days', {'trip_id': id, 'day_date': '2024-03-11'}),
      createOp('itinerary_days', {'trip_id': id, 'day_date': '2024-03-20'}),
    ]);
    expect(plan.items[0].block, isNull);
    expect(plan.items[1].block!.reason, BlockReason.duplicateRecord);
    expect(plan.items[2].block!.reason, BlockReason.invalidValue);
    await h.apply(
      await h.preview([
        createOp('itinerary_days', {'trip_id': id, 'day_date': '2024-03-11'}),
      ]),
    );

    final added = (await days(id)).single;
    expect(added['day_number'], 2);
    expect(added['day_date'], '2024-03-11');
  });
}
