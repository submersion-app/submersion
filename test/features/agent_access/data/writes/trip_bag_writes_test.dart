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

  Future<void> item(String id, String type, {String owner = kDiverA}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Gear $id',
          type: type,
          createdAt: kSeedTime,
          updatedAt: kSeedTime,
          diverId: Value(owner),
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

  test('an empty bag is the same as leaving it out', () async {
    final plan = await h.preview([
      update(bags: {'duffel': <String>[]}),
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

  test(
    'the preview shows gear coming out of a bag the change unpacks',
    () async {
      await h.run([
        update(
          bags: {
            'duffel': ['fins', 'mask'],
            'carry-on': [],
          },
        ),
      ]);
      final change = (await h.preview([
        update(
          gear: {
            'remove': ['duffel'],
          },
        ),
      ])).items.single.fields['bag_contents']!;
      expect(change.indirect, isTrue);
      expect(change.newValue, isEmpty);
    },
  );

  test('the preview shows unpacked gear leaving its bag', () async {
    await h.run([
      update(
        bags: {
          'duffel': ['fins', 'mask'],
        },
      ),
    ]);
    final change = (await h.preview([
      update(
        gear: {
          'remove': ['fins'],
        },
      ),
    ])).items.single.fields['bag_contents']!;
    expect(change.newValue, {
      'duffel': ['mask'],
    });
  });

  test('unpacking gear in no bag shows no bag change', () async {
    final plan = await h.preview([
      update(
        gear: {
          'remove': ['fins'],
        },
      ),
    ]);
    expect(plan.items.single.fields, isNot(contains('bag_contents')));
  });

  test('deleting a bag counts the packed gear it lets loose', () async {
    await h.run([
      update(
        bags: {
          'duffel': ['fins', 'mask'],
        },
      ),
    ]);
    final plan = await h.preview([deleteOp('equipment', 'duffel')]);
    expect(plan.items.single.reach.touched, {'trip_equipment': 2});
  });

  test('gear the agent cannot see stays in its bag', () async {
    await item('b-reg', 'regulator', owner: kDiverB);
    await db
        .into(db.tripEquipment)
        .insert(
          TripEquipmentCompanion.insert(
            id: 'pack-b-reg',
            tripId: tripId,
            equipmentId: 'b-reg',
            createdAt: kSeedTime,
            bagEquipmentId: const Value('duffel'),
          ),
        );
    final doc = (await h.records.one(
      'trips',
      tripId,
      include: ['bag_contents'],
    ))!;
    expect(doc['bag_contents'], isEmpty);

    await h.run([
      update(
        bags: {
          'duffel': ['fins'],
        },
      ),
    ]);
    expect((await packed())['b-reg'], 'duffel');
    await h.run([update(bags: {})]);
    expect((await packed())['b-reg'], 'duffel');
    expect((await packed())['fins'], isNull);
  });

  test('a bag that stopped being one reads empty and can be reset', () async {
    await h.run([
      update(
        bags: {
          'duffel': ['fins'],
        },
      ),
    ]);
    await db.customStatement(
      "UPDATE equipment SET type = 'other' WHERE id = 'duffel'",
    );
    final doc = (await h.records.one(
      'trips',
      tripId,
      include: ['bag_contents'],
    ))!;
    expect(doc['bag_contents'], isEmpty);
    expect((await h.preview([update(bags: {})])).items, isEmpty);

    await h.run([
      update(
        bags: {
          'carry-on': ['fins'],
        },
      ),
    ]);
    expect((await packed())['fins'], 'carry-on');
  });

  test('an earlier change in the set that makes gear a bag counts', () async {
    await h.run([
      updateOp('equipment', 'mask', {'type': 'bag'}),
      update(
        bags: {
          'mask': ['fins'],
        },
      ),
    ]);
    expect((await packed())['fins'], 'mask');
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

    test('for gear the agent cannot see', () async {
      await item('b-reg', 'regulator', owner: kDiverB);
      await db
          .into(db.tripEquipment)
          .insert(
            TripEquipmentCompanion.insert(
              id: 'pack-b-reg',
              tripId: tripId,
              equipmentId: 'b-reg',
              createdAt: kSeedTime,
            ),
          );
      final block = await blockFor({
        'duffel': ['b-reg'],
      });
      expect(block!.detail, contains('b-reg is not packed'));
    });

    test('for a bag an earlier change in the set makes not a bag', () async {
      final plan = await h.preview([
        updateOp('equipment', 'duffel', {'type': 'other'}),
        update(
          bags: {
            'duffel': ['fins'],
          },
        ),
      ]);
      expect(plan.items.last.block!.detail, contains('duffel is not a bag'));
    });

    test('for gear an earlier change in the set deletes', () async {
      final plan = await h.preview([
        deleteOp('equipment', 'fins'),
        update(
          bags: {
            'duffel': ['fins'],
          },
        ),
      ]);
      expect(plan.items.last.block!.detail, contains('fins is not packed'));
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
