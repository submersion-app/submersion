import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Dive types, roles and site types, as their settings pages keep them:
/// built-ins stay as the app ships them (a dive type may still be shown or
/// hidden), and a type or role a dive uses cannot be deleted.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<String> builtIn(String table) async =>
      (await db
              .customSelect(
                'SELECT id FROM $table WHERE is_built_in = 1 LIMIT 1',
              )
              .getSingle())
          .read<String>('id');

  Future<String> created(String entity, Map<String, Object?> fields) async =>
      (await h.run([createOp(entity, fields)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a built-in dive type shows or hides but keeps its name', () async {
    final id = await builtIn('dive_types');

    final plan = await h.preview([
      updateOp('dive_types', id, {'show_in_list_view': false}),
    ]);
    expect(plan.items.single.block, isNull);
    await h.apply(plan);
    expect((await h.one('dive_types', id))!['show_in_list_view'], isFalse);

    final refused = await h.preview([
      updateOp('dive_types', id, {'name': 'Renamed'}),
    ]);
    final gone = await h.preview([deleteOp('dive_types', id)]);
    expect(refused.items.single.block!.reason, BlockReason.notPermitted);
    expect(gone.items.single.block!.reason, BlockReason.notPermitted);
  });

  test('a built-in role or site type cannot change or go', () async {
    final role = await builtIn('dive_roles');
    final siteType = await builtIn('site_types');

    // One operation a preview: a set may name a record once.
    for (final op in [
      updateOp('dive_roles', role, {'name': 'Renamed'}),
      deleteOp('dive_roles', role),
      updateOp('site_types', siteType, {'name': 'Renamed'}),
      deleteOp('site_types', siteType),
    ]) {
      final plan = await h.preview([op]);
      expect(plan.items.single.block!.reason, BlockReason.notPermitted);
    }
  });

  test('a custom type, role and site type are created for the diver, '
      'renamed and deleted', () async {
    final type = await created('dive_types', {
      'name': 'Ice',
      'short_name': 'ICE',
    });
    final role = await created('dive_roles', {'name': 'Safety diver'});
    final siteType = await created('site_types', {'name': 'Quarry'});
    for (final (entity, id) in [
      ('dive_types', type),
      ('dive_roles', role),
      ('site_types', siteType),
    ]) {
      final doc = (await h.one(entity, id))!;
      expect(doc['diver_id'], kDiverA, reason: entity);
      expect(doc['is_built_in'], isFalse, reason: entity);
    }

    await h.run([
      updateOp('dive_types', type, {'name': 'Ice diving', 'short_name': null}),
      updateOp('dive_roles', role, {'name': 'Standby diver'}),
      updateOp('site_types', siteType, {'name': 'Flooded quarry'}),
    ]);
    expect((await h.one('dive_types', type))!['name'], 'Ice diving');
    expect((await h.one('dive_types', type))!['short_name'], isNull);
    expect((await h.one('dive_roles', role))!['name'], 'Standby diver');
    expect((await h.one('site_types', siteType))!['name'], 'Flooded quarry');

    await h.run([
      deleteOp('dive_types', type),
      deleteOp('dive_roles', role),
      deleteOp('site_types', siteType),
    ]);
    expect(await h.one('dive_types', type), isNull);
    expect(await h.one('dive_roles', role), isNull);
    expect(await h.one('site_types', siteType), isNull);
  });

  // These repositories put a new record with sort_order 0 after the last, so
  // a plan listing 0 would not be what is stored.
  test('a create with sort_order 0 is refused, any other slot stays', () async {
    final plan = await h.preview([
      createOp('dive_types', {'name': 'Ice', 'sort_order': 0}),
      createOp('site_types', {'name': 'Quarry', 'sort_order': 0}),
      createOp('tank_presets', {
        'display_name': 'Twin 7',
        'volume_l': 14.0,
        'working_pressure_bar': 300.0,
        'material': 'steel',
        'sort_order': 0,
      }),
      createOp('dive_types', {'name': 'Cave', 'sort_order': 4}),
    ]);

    for (final item in plan.items.take(3)) {
      expect(item.block!.reason, BlockReason.invalidValue, reason: item.entity);
      expect(item.block!.detail, contains('sort_order'));
    }
    expect(plan.items[3].block, isNull);
  });

  test('a custom dive type or role a dive uses cannot be deleted', () async {
    final type = await created('dive_types', {'name': 'Ice'});
    final role = await created('dive_roles', {'name': 'Safety diver'});
    await db
        .into(db.diveDiveTypes)
        .insert(
          DiveDiveTypesCompanion.insert(
            id: 'ddt',
            diveId: 'd1',
            diveTypeId: type,
            createdAt: t,
          ),
        );
    await db
        .into(db.diveDiverRoles)
        .insert(
          DiveDiverRolesCompanion.insert(
            id: 'ddr',
            diveId: 'd1',
            roleId: role,
            createdAt: t,
          ),
        );

    final plan = await h.preview([
      deleteOp('dive_types', type),
      deleteOp('dive_roles', role),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.notPermitted);
    }
  });

  test(
    'a dive type whose dives the set first deletes can be deleted',
    () async {
      final type = await created('dive_types', {'name': 'Ice'});
      await db
          .into(db.diveDiveTypes)
          .insert(
            DiveDiveTypesCompanion.insert(
              id: 'ddt',
              diveId: 'd1',
              diveTypeId: type,
              createdAt: t,
            ),
          );

      final plan = await h.preview([
        deleteOp('dives', 'd1'),
        deleteOp('dive_types', type),
      ]);

      expect(plan.items.last.block, isNull);
      await h.apply(plan);
      expect(await h.one('dive_types', type), isNull);
    },
  );

  test(
    'a dive type the set first takes off its dives can be deleted',
    () async {
      final type = await created('dive_types', {'name': 'Ice'});
      await db
          .into(db.diveDiveTypes)
          .insert(
            DiveDiveTypesCompanion.insert(
              id: 'ddt',
              diveId: 'd1',
              diveTypeId: type,
              createdAt: t,
            ),
          );
      Map<String, Object?> types(String dive, Map<String, Object?> change) => {
        'op': 'update',
        'entity': 'dives',
        'id': dive,
        'relations': {'types': change},
      };

      final plan = await h.preview([
        types('d1', {
          'remove': [type],
        }),
        deleteOp('dive_types', type),
      ]);

      expect(plan.items.last.block, isNull);
      await h.apply(plan);
      expect(await h.one('dive_types', type), isNull);
    },
  );

  test('deleting a custom site type unlinks its sites', () async {
    final siteType = await created('site_types', {'name': 'Quarry'});
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Blue Hole',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.siteSiteTypes)
        .insert(
          SiteSiteTypesCompanion.insert(
            id: 'sst',
            siteId: 's1',
            siteTypeId: siteType,
            createdAt: t,
          ),
        );

    final plan = await h.preview([deleteOp('site_types', siteType)]);
    expect(plan.items.single.reach.unlinked, {'site_site_types': 1});

    await h.apply(plan);
    expect(await db.select(db.siteSiteTypes).get(), isEmpty);
  });
}
