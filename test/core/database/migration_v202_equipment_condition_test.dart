import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';

/// v202: equipment condition intelligence, phase 1. Additive columns on six
/// tables, four new tables, and a one-time backfill of exposure defaults on
/// the built-in service kinds.

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<bool> _tableExists(AppDatabase db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(table)],
      )
      .get();
  return rows.isNotEmpty;
}

/// Every table the v202 block or the beforeOpen seed touches, as a v200
/// database would carry them.
void _createV200Fixture(dynamic rawDb) {
  rawDb.execute('PRAGMA user_version = 200');
  rawDb.execute('''
    CREATE TABLE divers (
      id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)
  ''');
  rawDb.execute('''
    CREATE TABLE equipment (
      id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      purchase_currency TEXT NOT NULL DEFAULT 'USD',
      notes TEXT NOT NULL DEFAULT '', is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE dive_tanks (
      id TEXT NOT NULL PRIMARY KEY, dive_id TEXT NOT NULL, equipment_id TEXT,
      o2_percent REAL NOT NULL DEFAULT 21.0,
      he_percent REAL NOT NULL DEFAULT 0.0,
      tank_order INTEGER NOT NULL DEFAULT 0,
      tank_role TEXT NOT NULL DEFAULT 'backGas', transmitter_serial TEXT,
      computer_id TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE incidents (
      id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, dive_id TEXT,
      occurred_at INTEGER NOT NULL, category TEXT NOT NULL,
      severity TEXT NOT NULL, narrative TEXT NOT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE trips (
      id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
      start_date INTEGER NOT NULL, end_date INTEGER NOT NULL,
      trip_type TEXT NOT NULL DEFAULT 'shore', notes TEXT NOT NULL DEFAULT '',
      is_shared INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE service_kinds (
      id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
      applicable_types TEXT NOT NULL DEFAULT '[]',
      default_interval_days INTEGER, default_interval_dives INTEGER,
      default_interval_hours REAL, default_cost REAL, default_currency TEXT,
      default_category TEXT, auto_attach INTEGER NOT NULL DEFAULT 0,
      is_built_in INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE service_schedules (
      id TEXT NOT NULL PRIMARY KEY, equipment_id TEXT NOT NULL,
      service_kind_id TEXT NOT NULL, interval_days INTEGER,
      interval_dives INTEGER, interval_hours REAL, default_cost REAL,
      default_currency TEXT, anchor_date INTEGER,
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE diver_settings (
      id TEXT NOT NULL PRIMARY KEY, diver_id TEXT NOT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)
  ''');
  rawDb.execute(
    "INSERT INTO service_kinds (id, name, applicable_types, "
    "default_interval_days, default_interval_dives, is_built_in, "
    "created_at, updated_at) VALUES ('regulator-service', 'Regulator service', "
    "'[\"regulator\"]', 365, 100, 1, 1, 1)",
  );
  rawDb.execute(
    "INSERT INTO service_kinds (id, name, applicable_types, "
    "default_interval_days, is_built_in, created_at, updated_at) VALUES "
    "('o2-clean', 'O2 clean', '[\"tank\"]', 365, 1, 1, 1)",
  );
  rawDb.execute(
    "INSERT INTO service_kinds (id, name, applicable_types, "
    "default_interval_days, is_built_in, created_at, updated_at) VALUES "
    "('transmitter-battery', 'Transmitter battery', '[\"transmitter\"]', "
    "365, 1, 1, 1)",
  );
  rawDb.execute(
    "INSERT INTO service_kinds (id, name, is_built_in, created_at, "
    "updated_at) VALUES ('disinfect', 'Disinfect', 0, 1, 1)",
  );
}

void main() {
  test('v202 is the current schema version and is in the ladder', () {
    // Relaxed once v203 (equipment assemblies) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(202));
    expect(AppDatabase.migrationVersions, contains(202));
  });

  test('a fresh database has every v202 column and table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _columns(db, 'equipment'), contains('parent_equipment_id'));
    expect(
      await _columns(db, 'dive_tanks'),
      contains('regulator_equipment_id'),
    );
    expect(await _columns(db, 'incidents'), contains('equipment_id'));
    expect(
      await _columns(db, 'trips'),
      containsAll(['expected_dives', 'expected_runtime_minutes']),
    );
    expect(await _columns(db, 'service_kinds'), contains('exposure_intervals'));
    expect(
      await _columns(db, 'service_schedules'),
      contains('exposure_intervals'),
    );
    expect(
      await _columns(db, 'diver_settings'),
      containsAll([
        'cold_water_threshold_c',
        'deep_dive_threshold_m',
        'high_o2_threshold_percent',
      ]),
    );
    for (final table in [
      'dive_sensor_summaries',
      'equipment_observations',
      'equipment_findings',
      'equipment_condition_reviews',
    ]) {
      expect(await _tableExists(db, table), isTrue, reason: table);
    }
  });

  test('a fresh database seeds exposure defaults on built-in kinds', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    Future<String> col(String id, String column) async =>
        (await db
                .customSelect(
                  'SELECT $column AS v FROM service_kinds WHERE id = ?',
                  variables: [Variable.withString(id)],
                )
                .getSingle())
            .read<String>('v');

    expect(
      decodeExposureIntervals(
        await col('regulator-service', 'exposure_intervals'),
      ),
      {ExposureUnit.coldDives: 50.0},
    );
    expect(
      decodeExposureIntervals(await col('o2-clean', 'exposure_intervals')),
      {ExposureUnit.o2Hours: 50.0},
    );
    expect(
      decodeExposureIntervals(await col('drysuit-seals', 'exposure_intervals')),
      {ExposureUnit.saltHours: 200.0},
    );
    expect(await col('o2-clean', 'applicable_types'), '["tank","regulator"]');
    expect(
      await col('computer-battery', 'applicable_types'),
      '["computer","battery"]',
    );
    expect(
      await col('transmitter-battery', 'applicable_types'),
      '["transmitter","battery"]',
    );
    expect(
      await col('o2-cell-replacement', 'applicable_types'),
      '["rebreather","o2Cell"]',
    );
    final hours = await db
        .customSelect(
          "SELECT default_interval_hours AS h FROM service_kinds "
          "WHERE id = 'transmitter-battery'",
        )
        .getSingle();
    expect(hours.read<double>('h'), 250.0);
  });

  test(
    'a database stranded before v202 gains the columns and the backfill',
    () async {
      final db = AppDatabase(NativeDatabase.memory(setup: _createV200Fixture));
      addTearDown(db.close);

      expect(await _columns(db, 'equipment'), contains('parent_equipment_id'));
      expect(
        await _columns(db, 'service_kinds'),
        contains('exposure_intervals'),
      );
      expect(await _tableExists(db, 'equipment_findings'), isTrue);

      Future<String> col(String id, String column) async =>
          (await db
                  .customSelect(
                    'SELECT $column AS v FROM service_kinds WHERE id = ?',
                    variables: [Variable.withString(id)],
                  )
                  .getSingle())
              .read<String>('v');

      expect(
        decodeExposureIntervals(
          await col('regulator-service', 'exposure_intervals'),
        ),
        {ExposureUnit.coldDives: 50.0},
      );
      expect(await col('o2-clean', 'applicable_types'), '["tank","regulator"]');
      expect(
        await col('transmitter-battery', 'applicable_types'),
        '["transmitter","battery"]',
      );
      expect(
        decodeExposureIntervals(await col('disinfect', 'exposure_intervals')),
        isEmpty,
        reason: 'a custom kind gets no defaults',
      );
      // The built-in regulator row keeps its own calendar and dive intervals.
      final reg = await db
          .customSelect(
            "SELECT default_interval_days AS d, default_interval_dives AS n "
            "FROM service_kinds WHERE id = 'regulator-service'",
          )
          .getSingle();
      expect(reg.read<int>('d'), 365);
      expect(reg.read<int>('n'), 100);
    },
  );

  test('exposure thresholds default on a settings row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'A', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO diver_settings (id, diver_id, created_at, updated_at) "
      "VALUES ('s1', 'd1', 1, 1)",
    );
    final row = await db
        .customSelect(
          'SELECT cold_water_threshold_c AS c, deep_dive_threshold_m AS d, '
          "high_o2_threshold_percent AS o FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<double>('c'), 10.0);
    expect(row.read<double>('d'), 30.0);
    expect(row.read<double>('o'), 40.0);
  });
}
