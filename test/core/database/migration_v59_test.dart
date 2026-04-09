import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Tests for the v58 -> v59 migration that copies legacy pressure data
/// from dive_profiles.pressure into tank_pressure_profiles.
void main() {
  group('Migration v59 - legacy pressure data migration', () {
    test(
      'migrates pressure from dive_profiles into tank_pressure_profiles',
      () async {
        final nativeDb = NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA user_version = 58');

            // Minimal schema at v58
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
              working_pressure REAL,
              start_pressure REAL,
              end_pressure REAL,
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

            // Insert a dive with a tank and profile rows that have pressure
            rawDb.execute('''
            INSERT INTO dives (id, dive_date_time, created_at, updated_at)
            VALUES ('d1', 0, 0, 0)
          ''');
            rawDb.execute('''
            INSERT INTO dive_tanks (id, dive_id, volume, working_pressure,
              start_pressure, end_pressure, o2_percent, he_percent,
              tank_order, tank_role)
            VALUES ('t1', 'd1', 11.1, 207.0, 200.0, 50.0, 21.0, 0.0,
              0, 'backGas')
          ''');
            rawDb.execute('''
            INSERT INTO dive_profiles (id, dive_id, timestamp, depth,
              pressure, is_primary)
            VALUES ('p1', 'd1', 0, 0.0, 200.0, 1)
          ''');
            rawDb.execute('''
            INSERT INTO dive_profiles (id, dive_id, timestamp, depth,
              pressure, is_primary)
            VALUES ('p2', 'd1', 60, 15.0, 190.0, 1)
          ''');
            rawDb.execute('''
            INSERT INTO dive_profiles (id, dive_id, timestamp, depth,
              pressure, is_primary)
            VALUES ('p3', 'd1', 120, 20.0, 180.0, 1)
          ''');
            // A profile point with no pressure (should be skipped)
            rawDb.execute('''
            INSERT INTO dive_profiles (id, dive_id, timestamp, depth,
              pressure, is_primary)
            VALUES ('p4', 'd1', 180, 10.0, NULL, 1)
          ''');
          },
        );

        final db = AppDatabase(nativeDb);
        addTearDown(() => db.close());

        // Trigger migration
        await db.customSelect('SELECT 1 FROM dive_profiles').get();

        // Verify pressure data was migrated to tank_pressure_profiles
        final rows = await db
            .customSelect(
              "SELECT * FROM tank_pressure_profiles WHERE dive_id = 'd1' "
              "ORDER BY timestamp ASC",
            )
            .get();

        expect(rows.length, 3); // Only 3 rows had non-null pressure
        // Migrated rows reuse the dive_profile id for efficiency
        expect(rows[0].read<String>('id'), 'p1');
        expect(rows[0].read<String>('tank_id'), 't1');
        expect(rows[0].read<int>('timestamp'), 0);
        expect(rows[0].read<double>('pressure'), 200.0);
        expect(rows[1].read<String>('id'), 'p2');
        expect(rows[1].read<int>('timestamp'), 60);
        expect(rows[1].read<double>('pressure'), 190.0);
        expect(rows[2].read<String>('id'), 'p3');
        expect(rows[2].read<int>('timestamp'), 120);
        expect(rows[2].read<double>('pressure'), 180.0);
      },
    );

    test('skips dive with no tanks', () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 58');

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
              working_pressure REAL,
              start_pressure REAL,
              end_pressure REAL,
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

          // Dive with pressure data but NO tanks
          rawDb.execute('''
            INSERT INTO dives (id, dive_date_time, created_at, updated_at)
            VALUES ('d-no-tank', 0, 0, 0)
          ''');
          rawDb.execute('''
            INSERT INTO dive_profiles (id, dive_id, timestamp, depth,
              pressure, is_primary)
            VALUES ('p1', 'd-no-tank', 0, 0.0, 200.0, 1)
          ''');
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      await db.customSelect('SELECT 1 FROM dive_profiles').get();

      // No rows should be in tank_pressure_profiles because dive has no tank
      final rows = await db
          .customSelect("SELECT * FROM tank_pressure_profiles")
          .get();

      expect(rows.length, 0);
    });

    test('skips dive that already has tank_pressure_profiles rows', () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 58');

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
              working_pressure REAL,
              start_pressure REAL,
              end_pressure REAL,
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

          // Dive with tank, legacy pressure, AND existing
          // tank_pressure_profiles
          rawDb.execute('''
            INSERT INTO dives (id, dive_date_time, created_at, updated_at)
            VALUES ('d-existing', 0, 0, 0)
          ''');
          rawDb.execute('''
            INSERT INTO dive_tanks (id, dive_id, volume, working_pressure,
              start_pressure, end_pressure, o2_percent, he_percent,
              tank_order, tank_role)
            VALUES ('t1', 'd-existing', 11.1, 207.0, 200.0, 50.0, 21.0,
              0.0, 0, 'backGas')
          ''');
          rawDb.execute('''
            INSERT INTO dive_profiles (id, dive_id, timestamp, depth,
              pressure, is_primary)
            VALUES ('p1', 'd-existing', 0, 0.0, 200.0, 1)
          ''');
          // Pre-existing tank_pressure_profiles row - migration should skip
          rawDb.execute('''
            INSERT INTO tank_pressure_profiles (id, dive_id, tank_id,
              timestamp, pressure)
            VALUES ('existing-tpp', 'd-existing', 't1', 0, 200.0)
          ''');
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      await db.customSelect('SELECT 1 FROM dive_profiles').get();

      // Should still have only the 1 pre-existing row, no duplicates
      final rows = await db
          .customSelect("SELECT * FROM tank_pressure_profiles")
          .get();

      expect(rows.length, 1);
      expect(rows.first.read<String>('id'), 'existing-tpp');
    });

    test('uses first tank by rowid for multi-tank dives', () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 58');

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
              working_pressure REAL,
              start_pressure REAL,
              end_pressure REAL,
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

          // Dive with two tanks - first tank inserted gets lowest rowid
          rawDb.execute('''
            INSERT INTO dives (id, dive_date_time, created_at, updated_at)
            VALUES ('d-multi', 0, 0, 0)
          ''');
          rawDb.execute('''
            INSERT INTO dive_tanks (id, dive_id, volume, working_pressure,
              start_pressure, end_pressure, o2_percent, he_percent,
              tank_order, tank_role)
            VALUES ('first-tank', 'd-multi', 11.1, 207.0, 200.0, 50.0,
              21.0, 0.0, 0, 'backGas')
          ''');
          rawDb.execute('''
            INSERT INTO dive_tanks (id, dive_id, volume, working_pressure,
              start_pressure, end_pressure, o2_percent, he_percent,
              tank_order, tank_role)
            VALUES ('second-tank', 'd-multi', 7.0, 207.0, 200.0, 100.0,
              50.0, 0.0, 1, 'stage')
          ''');
          rawDb.execute('''
            INSERT INTO dive_profiles (id, dive_id, timestamp, depth,
              pressure, is_primary)
            VALUES ('p1', 'd-multi', 0, 0.0, 200.0, 1)
          ''');
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      await db.customSelect('SELECT 1 FROM dive_profiles').get();

      final rows = await db
          .customSelect("SELECT * FROM tank_pressure_profiles")
          .get();

      expect(rows.length, 1);
      // Should be assigned to the first tank by rowid
      expect(rows.first.read<String>('tank_id'), 'first-tank');
    });
  });
}
