import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v100 creates the three dive plan tables with hlc columns', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 99');
        // Minimal parents so FK references resolve.
        rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    for (final table in [
      'dive_plans',
      'dive_plan_tanks',
      'dive_plan_segments',
    ]) {
      final cols = await db.customSelect("PRAGMA table_info('$table')").get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('id'), reason: '$table missing id');
      expect(names, contains('hlc'), reason: '$table missing hlc');
      expect(
        names,
        contains('created_at'),
        reason: '$table missing created_at',
      );
      expect(
        names,
        contains('updated_at'),
        reason: '$table missing updated_at',
      );
    }

    final planCols = await db
        .customSelect("PRAGMA table_info('dive_plans')")
        .get();
    final planNames = planCols.map((c) => c.read<String>('name')).toSet();
    expect(
      planNames,
      containsAll([
        'diver_id',
        'name',
        'notes',
        'mode',
        'site_id',
        'source_dive_id',
        'linked_dive_id',
        'altitude',
        'water_type',
        'gf_low',
        'gf_high',
        'descent_rate',
        'ascent_rate',
        'last_stop_depth',
        'gas_switch_stop_seconds',
        'air_break_o2_seconds',
        'air_break_break_seconds',
        'sac_bottom',
        'sac_deco',
        'sac_stressed',
        'reserve_pressure',
        'surface_interval_seconds',
        'setpoint_low',
        'setpoint_high',
        'setpoint_switch_depth',
        'deviation_depth_delta',
        'deviation_time_minutes',
        'turn_pressure_rule',
        'turn_pressure_fraction',
        'summary_max_depth',
        'summary_runtime_seconds',
        'summary_tts_seconds',
      ]),
    );

    final tankCols = await db
        .customSelect("PRAGMA table_info('dive_plan_tanks')")
        .get();
    final tankNames = tankCols.map((c) => c.read<String>('name')).toSet();
    expect(
      tankNames,
      containsAll([
        'plan_id',
        'name',
        'volume',
        'working_pressure',
        'start_pressure',
        'gas_o2',
        'gas_he',
        'role',
        'material',
        'preset_name',
        'sort_order',
      ]),
    );

    final segCols = await db
        .customSelect("PRAGMA table_info('dive_plan_segments')")
        .get();
    final segNames = segCols.map((c) => c.read<String>('name')).toSet();
    expect(
      segNames,
      containsAll([
        'plan_id',
        'type',
        'start_depth',
        'end_depth',
        'duration_seconds',
        'tank_id',
        'gas_o2',
        'gas_he',
        'rate',
        'switch_to_tank_id',
        'sort_order',
      ]),
    );

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_dive_plan%'",
        )
        .get();
    final indexNames = indexes.map((r) => r.read<String>('name')).toSet();
    expect(indexNames, contains('idx_dive_plan_tanks_plan_id'));
    expect(indexNames, contains('idx_dive_plan_segments_plan_id'));
  });

  test(
    'recovers databases stranded at v100 by parallel-branch collisions',
    () async {
      // A live database that claimed user_version 100 on a parallel branch
      // (without the plan tables) must be healed by the beforeOpen re-assert.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 100');
          rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute(
            'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)',
          );
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      for (final table in [
        'dive_plans',
        'dive_plan_tanks',
        'dive_plan_segments',
      ]) {
        final cols = await db.customSelect("PRAGMA table_info('$table')").get();
        expect(cols, isNotEmpty, reason: '$table was not created');
      }
    },
  );

  test('v100 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 100);
    expect(AppDatabase.migrationVersions, contains(100));
  });

  test('fresh database exposes the plan tables via Drift', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());
    expect(await db.select(db.divePlans).get(), isEmpty);
    expect(await db.select(db.divePlanTanks).get(), isEmpty);
    expect(await db.select(db.divePlanSegments).get(), isEmpty);
  });
}
