import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A trip's bags (issue #4945): bag_contents names each packed bag with the
/// packed gear riding in it, as the gear tab moves gear between bags.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  late String tripId;

  Future<void> item(String id, String type) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Gear $id',
          type: type,
          createdAt: kSeedTime,
          updatedAt: kSeedTime,
          diverId: const Value(kDiverA),
        ),
      );

  Map<String, Object?> update({
    Map<String, Object?>? bags,
    Map<String, Object?>? gear,
  }) => {
    'op': 'update',
    'entity': 'trips',
    'id': tripId,
    'fields': {'bag_contents': ?bags},
    'relations': {'equipment_ids': ?gear},
  };

  Future<Map<String, String?>> packed() async => {
    for (final row in await (db.select(
      db.tripEquipment,
    )..where((r) => r.tripId.equals(tripId))).get())
      row.equipmentId: row.bagEquipmentId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    tripId = (await h.run([
      createOp('trips', {
        'name': 'Red Sea',
        'start_date': '2024-03-10',
        'end_date': '2024-03-12',
      }),
    ])).created.single.id;
    await item('duffel', 'bag');
    await item('carry-on', 'bag');
    await item('fins', 'fins');
    await item('mask', 'mask');
    await h.run([
      update(
        gear: {
          'add': ['duffel', 'carry-on', 'fins', 'mask'],
        },
      ),
    ]);
  });
  tearDown(() => tearDownTestDatabase());

  test('gear goes into bags, and what is left out rides loose', () async {
    await h.run([
      update(
        bags: {
          'duffel': ['fins', 'mask'],
        },
      ),
    ]);
    expect(await packed(), {
      'duffel': null,
      'carry-on': null,
      'fins': 'duffel',
      'mask': 'duffel',
    });

    await h.run([
      update(
        bags: {
          'carry-on': ['mask'],
        },
      ),
    ]);
    expect(await packed(), {
      'duffel': null,
      'carry-on': null,
      'fins': null,
      'mask': 'carry-on',
    });
  });

  test('a read shows the bags, so naming them again changes nothing', () async {
    await h.run([
      update(
        bags: {
          'duffel': ['fins'],
        },
      ),
    ]);
    final doc = (await h.records.one(
      'trips',
      tripId,
      include: ['bag_contents'],
    ))!;
    expect(doc['bag_contents'], {
      'duffel': ['fins'],
    });

    final plan = await h.preview([
      update(
        bags: {
          'duffel': ['fins'],
        },
      ),
    ]);
    expect(plan.items, isEmpty);
  });

  test('gear packed in the same change can go straight into a bag', () async {
    await item('torch', 'light');
    await h.run([
      update(
        gear: {
          'add': ['torch'],
        },
        bags: {
          'duffel': ['torch'],
        },
      ),
    ]);
    expect((await packed())['torch'], 'duffel');
  });

  test('unpacking a bag in the change leaves its contents loose', () async {
    await h.run([
      update(
        bags: {
          'duffel': ['fins'],
        },
      ),
    ]);
    await h.run([
      update(
        gear: {
          'remove': ['duffel'],
        },
      ),
    ]);
    expect(await packed(), {'carry-on': null, 'fins': null, 'mask': null});
  });

  group('is refused', () {
    Future<PlanBlock?> blockFor(Map<String, Object?> bags) async =>
        (await h.preview([update(bags: bags)])).items.single.block;

    test('for gear not packed on the trip', () async {
      await item('wetsuit', 'wetsuit');
      final block = await blockFor({
        'duffel': ['wetsuit'],
      });
      expect(block!.reason, BlockReason.invalidValue);
      expect(block.detail, contains('wetsuit is not packed'));
    });

    test('for gear the same change unpacks', () async {
      final plan = await h.preview([
        update(
          gear: {
            'remove': ['fins'],
          },
          bags: {
            'duffel': ['fins'],
          },
        ),
      ]);
      expect(plan.items.single.block!.detail, contains('fins is not packed'));
    });

    test('for a key that is not a bag', () async {
      final block = await blockFor({
        'fins': ['mask'],
      });
      expect(block!.detail, contains('fins is not a bag'));
    });

    test('for a bag inside another bag', () async {
      final block = await blockFor({
        'duffel': ['carry-on'],
      });
      expect(block!.detail, contains('carry-on is a bag'));
    });

    test('for gear in two bags', () async {
      final block = await blockFor({
        'duffel': ['fins'],
        'carry-on': ['fins'],
      });
      expect(block!.detail, contains('fins is in more than one bag'));
    });

    test('on a new trip, before anything is packed', () async {
      final plan = await h.preview([
        createOp('trips', {
          'name': 'Bonaire',
          'start_date': '2024-05-01',
          'end_date': '2024-05-02',
          'bag_contents': {'duffel': <String>[]},
        }),
      ]);
      expect(plan.items.single.block!.reason, BlockReason.notPermitted);
    });
  });
}
