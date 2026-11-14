import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_set_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Equipment sets, as the sets page keeps them: members the owner can use,
/// one default per diver, the figure and the places a set applies near.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> gear(String id, {String owner = kDiverA}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Gear $id',
          type: 'wing',
          createdAt: t,
          updatedAt: t,
          diverId: Value(owner),
        ),
      );

  Future<String> created(Map<String, Object?> fields) async =>
      (await h.run([createOp('equipment_sets', fields)])).created.single.id;

  Map<String, Object?> members(
    String id, {
    List<String> add = const [],
    List<String> remove = const [],
  }) => {
    'op': 'update',
    'entity': 'equipment_sets',
    'id': id,
    'relations': {
      'equipment_ids': {'add': add, 'remove': remove},
    },
  };

  Future<Set<String>> memberIds(String id) async => {
    for (final row in await (db.select(
      db.equipmentSetItems,
    )..where((r) => r.setId.equals(id))).get())
      row.equipmentId,
  };

  Future<List<EquipmentSetGeofence>> fences(String id) => (db.select(
    db.equipmentSetGeofences,
  )..where((g) => g.setId.equals(id))).get();

  Map<String, Object?> fence(double lat, {double radius = 15000}) => {
    'label': 'Reef',
    'latitude': lat,
    'longitude': 34.0,
    'radius_m': radius,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await gear('wing');
    await gear('fins');
  });
  tearDown(() => tearDownTestDatabase());

  test('a set is created, renamed and deleted with its geofences', () async {
    final id = await created({
      'name': 'Red Sea',
      'geofences': [fence(27.0)],
    });
    expect((await h.one('equipment_sets', id))!['name'], 'Red Sea');
    expect(await fences(id), hasLength(1));

    await h.run([
      updateOp('equipment_sets', id, {'name': 'Egypt'}),
    ]);
    expect((await h.one('equipment_sets', id))!['name'], 'Egypt');

    final plan = await h.preview([deleteOp('equipment_sets', id)]);
    expect(plan.items.single.reach.parts['equipment_set_geofences'], 1);
    await h.apply(plan);
    expect(await h.one('equipment_sets', id), isNull);
    expect(await fences(id), isEmpty);
  });

  test('members are added and removed', () async {
    final id = await created({'name': 'Warm'});

    await h.run([
      members(id, add: ['wing', 'fins']),
    ]);
    expect(await memberIds(id), {'wing', 'fins'});
    await h.run([
      members(id, remove: ['wing']),
    ]);
    expect(await memberIds(id), {'fins'});
  });

  // A set applies the gear of the sets it includes, and a dive tags that
  // gear with the set picked. So including a set, or editing one that is
  // included, reaches the planned dives of the outer set (issue #4525).
  test('an include change, and a member change on an included set, follow '
      'on the outer set\'s planned dives', () async {
    final rig = await created({'name': 'Rig'});
    await h.run([
      members(rig, add: ['wing']),
    ]);
    final outer = await created({'name': 'Outer'});
    await h.dive('p1');
    await (db.update(db.dives)..where((d) => d.id.equals('p1'))).write(
      const DivesCompanion(isPlanned: Value(true)),
    );
    await gear('cam');
    await h.run([
      members(outer, add: ['cam']),
    ]);
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'p1',
            equipmentId: 'cam',
            viaSetId: Value(outer),
          ),
        );
    Future<Map<String, String?>> gearOn(String dive) async => {
      for (final row in await (db.select(
        db.diveEquipment,
      )..where((r) => r.diveId.equals(dive))).get())
        row.equipmentId: row.viaSetId,
    };
    Map<String, Object?> include(String id, List<String> add) => {
      'op': 'update',
      'entity': 'equipment_sets',
      'id': id,
      'relations': {
        'included_set_ids': {'add': add, 'remove': const <String>[]},
      },
    };

    final plan = await h.preview([
      include(outer, [rig]),
    ]);
    expect(plan.items.single.alsoChanges, {'dives': 1});
    await h.apply(plan);
    expect(await gearOn('p1'), {'cam': outer, 'wing': outer});

    // A dive carrying gear under both sets is one dive, counted once.
    await gear('reg');
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'p1',
            equipmentId: 'reg',
            viaSetId: Value(rig),
          ),
        );
    final inner = await h.preview([
      members(rig, add: ['fins']),
    ]);
    expect(inner.items.single.alsoChanges, {'dives': 1});
    await h.apply(inner);
    final after = await gearOn('p1');
    expect(after['fins'], isNotNull);
    expect(after.keys.toSet(), {'cam', 'wing', 'fins', 'reg'});
  });

  test('a member change follows on planned dives only (#4283)', () async {
    final id = await created({'name': 'Warm'});
    await h.run([
      members(id, add: ['wing']),
    ]);
    // d1 is logged, p1 planned; both carry the set.
    await h.dive('p1');
    await (db.update(db.dives)..where((d) => d.id.equals('p1'))).write(
      const DivesCompanion(isPlanned: Value(true)),
    );
    for (final dive in ['d1', 'p1']) {
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(
              diveId: dive,
              equipmentId: 'wing',
              viaSetId: Value(id),
            ),
          );
    }
    Future<Set<String>> gearOn(String dive) async => {
      for (final row in await (db.select(
        db.diveEquipment,
      )..where((r) => r.diveId.equals(dive))).get())
        row.equipmentId,
    };

    final plan = await h.preview([
      members(id, add: ['fins'], remove: ['wing']),
    ]);
    expect(plan.items.single.alsoChanges, {'dives': 1});
    await h.apply(plan);

    expect(await gearOn('p1'), {'fins'});
    expect(await gearOn('d1'), {'wing'});

    // The rewritten dive waits for afterApply, which rescans it once the
    // apply has committed, then lets it go.
    final entry = h.writes.named('equipment_sets')! as EquipmentSetWrites;
    expect(entry.pendingRescan, isEmpty);
    await entry.update(
      id,
      kDiverA,
      const RecordUpdate(
        relations: {
          'equipment_ids': RelationDelta(remove: {'fins'}),
        },
      ),
    );
    expect(entry.pendingRescan, {'p1'});
    await entry.afterApply(const [], ApplyRun());
    expect(entry.pendingRescan, isEmpty);
  });

  test('a member the owner cannot see is blocked', () async {
    await gear('theirs', owner: kDiverB);
    final id = await created({'name': 'Warm'});

    final plan = await h.preview([
      members(id, add: ['theirs']),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.otherProfileReference);
  });

  test('making a set the default clears the other', () async {
    final first = await created({'name': 'Warm'});
    final second = await created({'name': 'Cold'});
    await h.run([
      updateOp('equipment_sets', first, {'is_default': true}),
    ]);

    final plan = await h.preview([
      updateOp('equipment_sets', second, {'is_default': true}),
    ]);
    expect(plan.items.single.alsoChanges, {'equipment_sets': 1});
    await h.apply(plan);

    expect((await h.one('equipment_sets', first))!['is_default'], isFalse);
    expect((await h.one('equipment_sets', second))!['is_default'], isTrue);
  });

  test('a set no profile owns can be made the default', () async {
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: 'loose',
            name: 'Loose',
            createdAt: t,
            updatedAt: t,
          ),
        );

    final plan = await h.preview([
      updateOp('equipment_sets', 'loose', {'is_default': true}),
    ]);

    expect(plan.items.single.block, isNull);
  });

  // The set editor offers only gear in the kit.
  test('a member out of the kit is blocked', () async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'old',
            name: 'Old wing',
            type: 'wing',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
            status: const Value('retired'),
            isActive: const Value(false),
          ),
        );
    final id = await created({'name': 'Warm'});

    final plan = await h.preview([
      members(id, add: ['old']),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('a member leaving the kit earlier in the set is blocked', () async {
    final id = await created({'name': 'Warm'});

    final plan = await h.preview([
      updateOp('equipment', 'wing', {'status': 'sold'}),
      members(id, add: ['wing']),
    ]);

    expect(plan.items.last.block!.reason, BlockReason.invalidValue);
  });

  test('a new set cannot be made the default in its create', () async {
    final plan = await h.preview([
      createOp('equipment_sets', {'name': 'Warm', 'is_default': true}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('show_figure is written on its own', () async {
    final id = await created({'name': 'Warm'});

    await h.run([
      updateOp('equipment_sets', id, {'show_figure': false}),
    ]);

    expect((await h.one('equipment_sets', id))!['show_figure'], isFalse);
  });

  test('geofences are replaced whole and keep ids by position', () async {
    final id = await created({
      'name': 'Red Sea',
      'geofences': [fence(27.0), fence(28.0)],
    });
    final before = await fences(id);

    await h.run([
      updateOp('equipment_sets', id, {
        'geofences': [fence(27.5)],
      }),
    ]);
    final after = await fences(id);
    expect(after.single.latitude, 27.5);
    expect(after.single.id, before.first.id);

    final again = await h.preview([
      updateOp('equipment_sets', id, {
        'geofences': [fence(27.5)],
      }),
    ]);
    expect(again.unchanged.single.id, id);
  });

  test('a geofence radius outside 500 m to 100 km is refused', () async {
    final plan = await h.preview([
      createOp('equipment_sets', {
        'name': 'Tiny',
        'geofences': [fence(27.0, radius: 50)],
      }),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  group('what a set carries besides gear (issue #4525)', () {
    Future<List<String>> listOf(String table, String column, String id) async {
      final rows = await db
          .customSelect(
            'SELECT $column AS ref FROM $table WHERE set_id = ? '
            'ORDER BY sort_order',
            variables: [Variable.withString(id)],
          )
          .get();
      return [for (final r in rows) r.read<String>('ref')];
    }

    Map<String, Object?> link(
      String id,
      String relation, {
      List<String> add = const [],
      List<String> remove = const [],
    }) => {
      'op': 'update',
      'entity': 'equipment_sets',
      'id': id,
      'relations': {
        relation: {'add': add, 'remove': remove},
      },
    };

    setUp(() async {
      for (final id in ['p1', 'p2']) {
        await db
            .into(db.weightPresets)
            .insert(
              WeightPresetsCompanion.insert(
                id: id,
                displayName: id,
                diverId: const Value(kDiverA),
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
      await db
          .into(db.cylinderConfigs)
          .insert(
            CylinderConfigsCompanion.insert(
              id: 'c1',
              name: 'AL80',
              diverId: const Value(kDiverA),
              createdAt: t,
              updatedAt: t,
            ),
          );
    });

    test('weight presets, configurations and sets are linked and '
        'unlinked', () async {
      final rig = await created({'name': 'Rig'});
      final outer = await created({'name': 'Outer'});

      await h.run([
        {
          'op': 'update',
          'entity': 'equipment_sets',
          'id': outer,
          'relations': {
            'weight_preset_ids': {
              'add': ['p1', 'p2'],
            },
            'cylinder_config_ids': {
              'add': ['c1'],
            },
            'included_set_ids': {
              'add': [rig],
            },
          },
        },
      ]);
      expect(
        (await listOf(
          'equipment_set_weight_presets',
          'preset_id',
          outer,
        )).toSet(),
        {'p1', 'p2'},
      );
      expect(
        await listOf('equipment_set_cylinder_configs', 'config_id', outer),
        ['c1'],
      );
      expect(await listOf('equipment_set_includes', 'included_set_id', outer), [
        rig,
      ]);
      final document = (await h.one('equipment_sets', outer))!;
      expect(document['included_set_ids'], [rig]);
      expect(document['cylinder_config_ids'], ['c1']);

      await h.run([
        link(outer, 'weight_preset_ids', remove: ['p1']),
      ]);
      expect(await listOf('equipment_set_weight_presets', 'preset_id', outer), [
        'p2',
      ]);
    });

    test('an unrelated update keeps the lists', () async {
      final outer = await created({'name': 'Outer'});
      await h.run([
        link(outer, 'weight_preset_ids', add: ['p1']),
      ]);
      await h.run([
        {
          'op': 'update',
          'entity': 'equipment_sets',
          'id': outer,
          'fields': {'name': 'Renamed'},
          'relations': {
            'equipment_ids': {
              'add': ['wing'],
            },
          },
        },
      ]);
      expect((await h.one('equipment_sets', outer))!['name'], 'Renamed');
      expect(await listOf('equipment_set_weight_presets', 'preset_id', outer), [
        'p1',
      ]);
      expect(await memberIds(outer), {'wing'});
    });

    test('including a set that already includes sets is blocked', () async {
      final rig = await created({'name': 'Rig'});
      final outer = await created({'name': 'Outer'});
      final third = await created({'name': 'Third'});
      await h.run([
        link(outer, 'included_set_ids', add: [rig]),
      ]);

      final nested = await h.preview([
        link(third, 'included_set_ids', add: [outer]),
      ]);
      expect(nested.items.single.block, isNotNull);

      final itself = await h.preview([
        link(third, 'included_set_ids', add: [third]),
      ]);
      expect(itself.items.single.block, isNotNull);

      // Rig is included by Outer, so it cannot gain includes of its own.
      final inner = await h.preview([
        link(rig, 'included_set_ids', add: [third]),
      ]);
      expect(inner.items.single.block, isNotNull);
    });
  });
}
