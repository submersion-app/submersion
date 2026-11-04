import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Gear items, as the equipment edit page saves them: status decides
/// whether an item is in the kit, attributes are replaced whole, and a
/// save says what it does to service clocks and devices.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<String> created(Map<String, Object?> fields) async =>
      (await h.run([createOp('equipment', fields)])).created.single.id;

  Future<Map<String, Object?>> doc(String id) async =>
      (await h.one('equipment', id))!;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('an item is created, edited and deleted', () async {
    final id = await created({
      'name': ' Apeks XTX50 ',
      'type': 'regulator',
      'brand': 'Apeks',
    });
    expect((await doc(id))['name'], 'Apeks XTX50');
    expect((await doc(id))['diver_id'], kDiverA);

    await h.run([
      updateOp('equipment', id, {'brand': 'Aqualung', 'notes': 'Cold water'}),
    ]);
    expect((await doc(id))['brand'], 'Aqualung');
    expect((await doc(id))['notes'], 'Cold water');

    await h.run([deleteOp('equipment', id)]);
    expect(await h.one('equipment', id), isNull);
  });

  test(
    'retiring lists is_active, leaving wanted fills the purchase date',
    () async {
      final rig = await created({'name': 'Wing', 'type': 'wing'});
      final retire = await h.preview([
        updateOp('equipment', rig, {'status': 'retired'}),
      ]);
      final active = retire.items.single.fields['is_active']!;
      expect(
        [active.oldValue, active.newValue, active.indirect],
        [true, false, true],
      );
      await h.apply(retire);
      expect((await doc(rig))['is_active'], isFalse);

      final wish = await created({
        'name': 'Drysuit',
        'type': 'drysuit',
        'status': 'wanted',
      });
      expect((await doc(wish))['is_active'], isFalse);
      final buy = await h.preview([
        updateOp('equipment', wish, {'status': 'active'}),
      ]);
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      expect(buy.items.single.fields['purchase_date']!.newValue, today);
      expect(buy.items.single.fields['purchase_date']!.indirect, isTrue);
      await h.apply(buy);
      expect((await doc(wish))['purchase_date'], today);
      expect((await doc(wish))['is_active'], isTrue);
    },
  );

  test('a create lists the service clocks it attaches', () async {
    final kinds = await ServiceScheduleRepository().autoAttachKindsFor(
      type: EquipmentType.tank,
      diverId: kDiverA,
    );
    // The built-in tank kinds (hydro, visual) attach on their own.
    expect(kinds, isNotEmpty);
    final plan = await h.preview([
      createOp('equipment', {'name': 'AL80', 'type': 'tank'}),
    ]);

    expect(plan.items.single.alsoCreates, {'service_schedules': kinds.length});
    final id = (await h.apply(plan)).created.single.id;
    final clocks = await (db.select(
      db.serviceSchedules,
    )..where((s) => s.equipmentId.equals(id))).get();
    expect(clocks, hasLength(kinds.length));
  });

  test('renaming a device item lists the device it renames', () async {
    final id = await created({'name': 'Perdix', 'type': 'computer'});
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'dc1',
            name: 'Perdix',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
            equipmentId: Value(id),
          ),
        );

    final plan = await h.preview([
      updateOp('equipment', id, {'name': 'Perdix 2'}),
    ]);

    expect(plan.items.single.alsoChanges, {'dive_computers': 1});
  });

  test('attributes are replaced whole and a key must fit the type', () async {
    final id = await created({'name': 'Light', 'type': 'light'});
    final plan = await h.preview([
      updateOp('equipment', id, {
        'attributes': [
          {'key': 'lumens', 'value_num': 1200},
          {'key': 'Burn colour', 'is_custom': true, 'value_text': 'Warm'},
        ],
      }),
      createOp('equipment', {
        'name': 'Fins',
        'type': 'fins',
        'attributes': [
          {'key': 'lumens', 'value_num': 1200},
        ],
      }),
    ]);

    expect(plan.items.first.block, isNull);
    expect(plan.items.last.block!.reason, BlockReason.invalidValue);
    await h.apply(
      await h.preview([
        updateOp('equipment', id, {
          'attributes': [
            {'key': 'lumens', 'value_num': 1200},
            {'key': 'Burn colour', 'is_custom': true, 'value_text': 'Warm'},
          ],
        }),
      ]),
    );
    final again = await h.preview([
      updateOp('equipment', id, {
        'attributes': [
          {'key': 'lumens', 'value_num': 1200},
          {'key': 'Burn colour', 'is_custom': true, 'value_text': 'Warm'},
        ],
      }),
    ]);
    expect(again.unchanged.single.id, id);
  });

  test('a part fits only a type that holds it', () async {
    final light = await created({'name': 'Light', 'type': 'light'});
    final fins = await created({'name': 'Fins', 'type': 'fins'});

    final plan = await h.preview([
      createOp('equipment', {
        'name': 'Cell',
        'type': 'battery',
        'parent_equipment_id': light,
      }),
      createOp('equipment', {
        'name': 'Stray',
        'type': 'battery',
        'parent_equipment_id': fins,
      }),
      createOp('equipment', {
        'name': 'Mask',
        'type': 'mask',
        'parent_equipment_id': light,
      }),
    ]);

    expect(plan.items[0].block, isNull);
    expect(plan.items[1].block!.reason, BlockReason.invalidValue);
    expect(plan.items[2].block!.reason, BlockReason.invalidValue);
  });

  Future<void> tag(String id, {bool equipment = true}) => db
      .into(db.tags)
      .insert(
        TagsCompanion.insert(
          id: id,
          name: 'Tag $id',
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
          appliesToEquipment: Value(equipment),
        ),
      );

  Map<String, Object?> link(
    String id,
    String relation, {
    List<String> add = const [],
    List<String> remove = const [],
  }) => {
    'op': 'update',
    'entity': 'equipment',
    'id': id,
    'relations': {
      relation: {'add': add, 'remove': remove},
    },
  };

  Future<Set<String>> rows(String table, String column, String id) async => {
    for (final row
        in await db
            .customSelect(
              'SELECT $column AS v FROM $table WHERE equipment_id = ?',
              variables: [Variable.withString(id)],
            )
            .get())
      row.read<String>('v'),
  };

  test('an item gains and loses tags', () async {
    final id = await created({'name': 'Wing', 'type': 'wing'});
    await tag('cold');
    await tag('travel');

    await h.run([
      link(id, 'tags', add: ['cold', 'travel']),
    ]);
    expect(await rows('equipment_tags', 'tag_id', id), {'cold', 'travel'});
    await h.run([
      link(id, 'tags', remove: ['cold']),
    ]);
    expect(await rows('equipment_tags', 'tag_id', id), {'travel'});
  });

  test('a tag not used for equipment cannot link', () async {
    final id = await created({'name': 'Wing', 'type': 'wing'});
    await tag('dives-only', equipment: false);

    final plan = await h.preview([
      link(id, 'tags', add: ['dives-only']),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
    expect(plan.items.single.block!.detail, contains('dives-only'));
  });

  test('an item is shared and unshared', () async {
    final id = await created({'name': 'Wing', 'type': 'wing'});

    await h.run([
      link(id, 'shared_with', add: [kDiverB]),
    ]);
    expect(await rows('equipment_shares', 'diver_id', id), {kDiverB});
    await h.run([
      link(id, 'shared_with', remove: [kDiverB]),
    ]);
    expect(await rows('equipment_shares', 'diver_id', id), isEmpty);
  });

  test('sharing with the owner, an unknown profile or from an ownerless '
      'item is blocked', () async {
    final id = await created({'name': 'Wing', 'type': 'wing'});
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'nobodys',
            name: 'Loaner',
            type: 'wing',
            createdAt: t,
            updatedAt: t,
          ),
        );

    final plan = await h.preview([
      link(id, 'shared_with', add: [kDiverA]),
      link('nobodys', 'shared_with', add: [kDiverB]),
    ]);
    final unknown = await h.preview([
      link(id, 'shared_with', add: ['ghost']),
    ]);

    for (final item in plan.items) {
      expect(item.block, isNotNull, reason: item.id);
    }
    expect(unknown.items.single.block!.reason, BlockReason.unknownReference);
  });

  test('legacy service fields and is_active are not writable', () async {
    final id = await created({'name': 'Mask', 'type': 'mask'});

    for (final field in const {
      'last_service_date': '2026-01-01',
      'service_interval_days': 365,
      'is_active': false,
    }.entries) {
      final plan = await h.preview([
        updateOp('equipment', id, {field.key: field.value}),
      ]);
      expect(
        plan.items.single.block!.reason,
        BlockReason.unknownField,
        reason: field.key,
      );
    }
  });

  // An agent works across every profile and acts as a record's owner, so
  // another profile's item goes as that profile deletes it, shares and all.
  test('another profile\'s item is deleted as its owner', () async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'theirs',
            name: 'Their reg',
            type: 'regulator',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverB),
          ),
        );
    await db
        .into(db.equipmentShares)
        .insert(
          EquipmentSharesCompanion.insert(
            id: 'sh1',
            equipmentId: 'theirs',
            diverId: kDiverA,
            createdAt: t,
          ),
        );

    final plan = await h.preview([deleteOp('equipment', 'theirs')]);

    expect(plan.items.single.block, isNull);
    expect(plan.items.single.diverId, kDiverB);
    expect(plan.items.single.reach.parts['equipment_shares'], 1);
    await h.apply(plan);
    expect(await h.one('equipment', 'theirs', diverId: kDiverB), isNull);
  });

  // A photo only of the item goes with it; one a dive also holds stays and
  // loses its link to the item, as the repository's media split decides.
  test('a delete lists the photos it takes and the ones it keeps', () async {
    final id = await created({'name': 'Camera', 'type': 'camera'});
    Future<void> photo(String photoId, {String? dive}) => db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: photoId,
            filePath: '/$photoId.jpg',
            takenAt: const Value(t),
            createdAt: t,
            updatedAt: t,
            equipmentId: Value(id),
            diveId: Value(dive),
          ),
        );
    await photo('only-gear');
    await photo('on-dive', dive: 'd1');

    final plan = await h.preview([deleteOp('equipment', id)]);

    expect(plan.items.single.reach.records['media'], 1);
    expect(plan.items.single.reach.unlinked['media'], 1);
    await h.apply(plan);
    expect(await (db.select(db.media)).get(), hasLength(1));
  });

  test('a delete lists everything it takes', () async {
    final id = await created({'name': 'AL80', 'type': 'tank'});
    final plan = await h.preview([deleteOp('equipment', id)]);

    final reach = plan.items.single.reach;
    final clocks = await (db.select(
      db.serviceSchedules,
    )..where((s) => s.equipmentId.equals(id))).get();
    expect(clocks, isNotEmpty);
    expect(reach.parts['service_schedules'], clocks.length);
  });
}
