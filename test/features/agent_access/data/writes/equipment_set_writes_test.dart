import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
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
}
