import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v244 adds the DPV mission tables (issue #2086): dive_plan_missions,
/// dive_plan_mission_legs and dive_plan_mission_members, children of
/// dive_plans. Table-only rung, additive, floor stays at 240.

const _tables = [
  'dive_plan_missions',
  'dive_plan_mission_legs',
  'dive_plan_mission_members',
];

/// A database at [userVersion] holding only dive_plans, or nothing.
NativeDatabase _fixture({required int userVersion, bool withPlans = true}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      if (withPlans) {
        rawDb.execute('CREATE TABLE dive_plans (id TEXT NOT NULL PRIMARY KEY)');
      }
    },
  );
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<List<Map<String, Object?>>> _tableInfo(
  AppDatabase db,
  String table,
) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return [
    for (final r in rows)
      {
        'name': r.data['name'],
        'type': r.data['type'],
        'notnull': r.data['notnull'],
        'dflt_value': r.data['dflt_value'],
        'pk': r.data['pk'],
      },
  ];
}

Future<String?> _ddl(AppDatabase db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(table)],
      )
      .get();
  return rows.isEmpty ? null : rows.single.read<String?>('sql');
}

void main() {
  test('v244 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 244);
    expect(AppDatabase.migrationVersions, contains(244));
    expect(AppDatabase.migrationStepCount(242), 1);
    // Table-only rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a database from a v240 build gains the three tables', () async {
    final db = AppDatabase(_fixture(userVersion: 240));
    addTearDown(db.close);

    expect(
      await _columns(db, 'dive_plan_missions'),
      containsAll(<String>[
        'id',
        'plan_id',
        'battery_reserve_fraction',
        'default_current_speed_mps',
        'default_current_sets_toward_deg',
        'environment',
        'walk_speed_mps',
        'surface_swim_limit_m',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(
      await _columns(db, 'dive_plan_mission_legs'),
      containsAll(<String>[
        'id',
        'plan_id',
        'sort_order',
        'label',
        'distance_m',
        'depth_m',
        'heading_deg',
        'current_speed_mps',
        'current_sets_toward_deg',
        'shore_swim_m',
        'shore_walk_m',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(
      await _columns(db, 'dive_plan_mission_members'),
      containsAll(<String>[
        'id',
        'plan_id',
        'sort_order',
        'display_name',
        'buddy_id',
        'diver_id',
        'sac_bottom',
        'swim_speed_mps',
        'scooter_equipment_id',
        'scooter_name',
        'scooter_speed_mps',
        'scooter_burn_seconds',
        'tow_speed_factor',
        'tow_burn_factor',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('every table references its plan, and a plan has one mission', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    for (final table in _tables) {
      expect(
        await _ddl(db, table),
        contains('REFERENCES dive_plans (id)'),
        reason: table,
      );
    }
    expect(
      await _ddl(db, 'dive_plan_missions'),
      contains('UNIQUE ("plan_id")'),
    );
    // Soft links: a foreign key with no delete action would block deleting
    // the buddy, the diver or the equipment item.
    final members = await _ddl(db, 'dive_plan_mission_members');
    expect(members, isNot(contains('REFERENCES buddies')));
    expect(members, isNot(contains('REFERENCES divers')));
    expect(members, isNot(contains('REFERENCES equipment')));
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(_fixture(userVersion: 240));
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    for (final table in _tables) {
      expect(
        await _tableInfo(upgraded, table),
        await _tableInfo(fresh, table),
        reason: table,
      );
      expect(await _ddl(upgraded, table), await _ddl(fresh, table));
    }
  });

  test('a database already at v244 without the tables gains them', () async {
    // A database that arrives by restore or sync-adopt, or one a parallel
    // branch stamped with this version, never runs the rung; only the
    // beforeOpen backstop can add the tables there.
    final db = AppDatabase(
      _fixture(userVersion: AppDatabase.currentSchemaVersion),
    );
    addTearDown(db.close);

    for (final table in _tables) {
      expect(await _columns(db, table), contains('plan_id'), reason: table);
    }
  });

  test(
    'a database opened without dive_plans gains it and the mission tables',
    () async {
      // The v100 backstop re-creates dive_plans on every open (the
      // version-collision and restore cases). The mission tables must be
      // there too, whatever order the backstops run in, or every plan save
      // fails until the next launch.
      final db = AppDatabase(
        _fixture(
          userVersion: AppDatabase.currentSchemaVersion,
          withPlans: false,
        ),
      );
      addTearDown(db.close);

      expect(await _columns(db, 'dive_plans'), contains('id'));
      for (final table in _tables) {
        expect(await _columns(db, table), contains('plan_id'), reason: table);
      }
    },
  );
}
