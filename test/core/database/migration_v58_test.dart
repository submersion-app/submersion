import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Tests for the v57 -> v58 migration that converts pressure columns
/// from INTEGER to REAL in dive_tanks and tank_presets tables.
void main() {
  group('Migration v58 - pressure columns to REAL', () {
    test('fresh database has REAL pressure columns', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      await db.customSelect('SELECT 1').get();

      final columns = await db
          .customSelect("PRAGMA table_info('dive_tanks')")
          .get();
      final colTypes = {
        for (final row in columns)
          row.read<String>('name'): row.read<String>('type'),
      };

      expect(colTypes['working_pressure'], 'REAL');
      expect(colTypes['start_pressure'], 'REAL');
      expect(colTypes['end_pressure'], 'REAL');
    });

    test('v57 to v58 migration converts INTEGER pressure to REAL', () async {
      // Create a raw SQLite database at "v57" schema with INTEGER pressure
      // columns, then let AppDatabase migrate it to v58.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          // Set user_version to 57 so AppDatabase sees it as an existing DB
          rawDb.execute('PRAGMA user_version = 57');

          // Create minimal tables needed for the migration to run.
          // Only the tables involved in migration 58 plus their FK targets.
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT NOT NULL PRIMARY KEY,
              dive_date_time INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dive_tanks (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              equipment_id TEXT,
              volume REAL,
              working_pressure INTEGER,
              start_pressure INTEGER,
              end_pressure INTEGER,
              o2_percent REAL NOT NULL DEFAULT 21.0,
              he_percent REAL NOT NULL DEFAULT 0.0,
              tank_order INTEGER NOT NULL DEFAULT 0,
              tank_role TEXT NOT NULL DEFAULT 'backGas',
              tank_material TEXT,
              tank_name TEXT,
              preset_name TEXT
            )
          ''');
          rawDb.execute('''
            CREATE INDEX idx_dive_tanks_dive_id ON dive_tanks(dive_id)
          ''');
          rawDb.execute('''
            CREATE TABLE divers (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL DEFAULT ''
            )
          ''');
          rawDb.execute('''
            CREATE TABLE tank_presets (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              name TEXT NOT NULL,
              display_name TEXT NOT NULL,
              volume_liters REAL NOT NULL,
              working_pressure_bar INTEGER NOT NULL,
              material TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // Tables needed by migration v59 (legacy pressure data migration)
          rawDb.execute('''
            CREATE TABLE dive_profiles (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              timestamp INTEGER NOT NULL,
              depth REAL NOT NULL,
              pressure REAL,
              temperature REAL,
              is_primary INTEGER NOT NULL DEFAULT 1
            )
          ''');
          rawDb.execute('''
            CREATE TABLE tank_pressure_profiles (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              tank_id TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              pressure REAL NOT NULL
            )
          ''');

          // Insert test data with INTEGER pressures
          rawDb.execute('''
            INSERT INTO dives (id, dive_date_time, created_at, updated_at)
            VALUES ('d1', 0, 0, 0)
          ''');
          rawDb.execute('''
            INSERT INTO dive_tanks (id, dive_id, volume, working_pressure, start_pressure, end_pressure, o2_percent, he_percent, tank_order, tank_role)
            VALUES ('t1', 'd1', 11.1, 207, 200, 50, 21.0, 0.0, 0, 'backGas')
          ''');
          rawDb.execute('''
            INSERT INTO tank_presets (id, name, display_name, volume_liters, working_pressure_bar, material, created_at, updated_at)
            VALUES ('p1', 'custom', 'Custom', 12.0, 232, 'steel', 0, 0)
          ''');
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      // Trigger migration by accessing the database
      await db.customSelect('SELECT 1 FROM dive_tanks').get();

      // Verify dive_tanks columns are now REAL
      final dtCols = await db
          .customSelect("PRAGMA table_info('dive_tanks')")
          .get();
      final dtTypes = {
        for (final row in dtCols)
          row.read<String>('name'): row.read<String>('type'),
      };
      expect(dtTypes['working_pressure'], 'REAL');
      expect(dtTypes['start_pressure'], 'REAL');
      expect(dtTypes['end_pressure'], 'REAL');

      // Verify tank_presets column is now REAL
      final tpCols = await db
          .customSelect("PRAGMA table_info('tank_presets')")
          .get();
      final tpTypes = {
        for (final row in tpCols)
          row.read<String>('name'): row.read<String>('type'),
      };
      expect(tpTypes['working_pressure_bar'], 'REAL');

      // Verify data was preserved (integers cast to doubles)
      final tanks = await db
          .customSelect("SELECT * FROM dive_tanks WHERE id = 't1'")
          .get();
      expect(tanks.length, 1);
      expect(tanks.first.read<double?>('working_pressure'), 207.0);
      expect(tanks.first.read<double?>('start_pressure'), 200.0);
      expect(tanks.first.read<double?>('end_pressure'), 50.0);

      // Verify preset data preserved
      final presets = await db
          .customSelect("SELECT * FROM tank_presets WHERE id = 'p1'")
          .get();
      expect(presets.length, 1);
      expect(presets.first.read<double>('working_pressure_bar'), 232.0);

      // Verify index was recreated
      final indexes = await db
          .customSelect("PRAGMA index_list('dive_tanks')")
          .get();
      final indexNames = indexes.map((r) => r.read<String>('name')).toList();
      expect(indexNames, contains('idx_dive_tanks_dive_id'));
    });
  });
}
