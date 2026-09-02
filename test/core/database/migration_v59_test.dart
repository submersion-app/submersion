import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import 'test_fixtures.dart';

/// Tests for the v58 -> v59 migration that copies legacy pressure data
/// from dive_profiles.pressure into tank_pressure_profiles.
///
/// v182/v183 (which run in the same ladder, well past v59) pack whatever
/// tank_pressure_profiles rows this migration produced into
/// tank_pressure_series and drop the legacy table, so every assertion below
/// reads the packed series rather than the now-gone legacy table.
void main() {
  const codec = TankPressureSeriesCodec();

  Future<List<Map<String, Object?>>> tankSeriesFor(
    AppDatabase db,
    String diveId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM tank_pressure_series WHERE dive_id = ? '
          'ORDER BY tank_id',
          variables: [Variable<String>(diveId)],
        )
        .get();
    return rows.map((r) => r.data).toList();
  }

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
            // FK parents the v182/v183 rungs' series tables need to exist at
            // all (_assertProfileSeriesSchema), same as a real database has
            // carried since long before v58. dive_data_sources needs its
            // pre-v66 shape: the v66 rung rebuilds it and would otherwise
            // fail on a table this minimal.
            rawDb.execute(
              'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
            );
            createPreV66DiveDataSourcesTableRaw(rawDb);
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
              computer_id TEXT,
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

            createV71MediaTableRaw(rawDb);
          },
        );

        final db = AppDatabase(nativeDb);
        addTearDown(() => db.close());

        // Trigger migration (dive_profiles is long gone by the time this
        // resolves; the ladder drops it once v183 has packed everything).
        await db.customSelect('SELECT 1').get();

        final tanks = await tankSeriesFor(db, 'd1');
        expect(tanks, hasLength(1)); // Only one tank carried pressure data
        expect(tanks.single['tank_id'], 't1');
        expect(codec.decode(tanks.single['samples'] as dynamic), [
          // Only 3 samples: p4 had no pressure and never entered
          // tank_pressure_profiles.
          const TankPressureSample(timestamp: 0, pressure: 200.0),
          const TankPressureSample(timestamp: 60, pressure: 190.0),
          const TankPressureSample(timestamp: 120, pressure: 180.0),
        ]);
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
          // FK parents the v182/v183 rungs' series tables need to exist at
          // all (_assertProfileSeriesSchema), same as a real database has
          // carried since long before v58. dive_data_sources needs its
          // pre-v66 shape: the v66 rung rebuilds it and would otherwise fail
          // on a table this minimal.
          rawDb.execute(
            'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
          );
          createPreV66DiveDataSourcesTableRaw(rawDb);
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
              computer_id TEXT,
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

          createV71MediaTableRaw(rawDb);
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      await db.customSelect('SELECT 1').get();

      // No tank series because the dive never had a tank, so the pressure
      // reading was never a candidate for the v59 rung to migrate.
      expect(await tankSeriesFor(db, 'd-no-tank'), isEmpty);
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
          // FK parents the v182/v183 rungs' series tables need to exist at
          // all (_assertProfileSeriesSchema), same as a real database has
          // carried since long before v58. dive_data_sources needs its
          // pre-v66 shape: the v66 rung rebuilds it and would otherwise fail
          // on a table this minimal.
          rawDb.execute(
            'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
          );
          createPreV66DiveDataSourcesTableRaw(rawDb);
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
              computer_id TEXT,
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
          // tank_pressure_profiles. The profile row's pressure (999.0)
          // deliberately differs from the pre-existing series row's (200.0):
          // if the v59 rung mistakenly re-migrated it anyway, the packed
          // series below would carry both values instead of just one.
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
            VALUES ('p1', 'd-existing', 0, 0.0, 999.0, 1)
          ''');
          // Pre-existing tank_pressure_profiles row - migration should skip
          rawDb.execute('''
            INSERT INTO tank_pressure_profiles (id, dive_id, tank_id,
              timestamp, pressure)
            VALUES ('existing-tpp', 'd-existing', 't1', 0, 200.0)
          ''');

          createV71MediaTableRaw(rawDb);
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      await db.customSelect('SELECT 1').get();

      // Still just the 1 pre-existing reading packed, not a second one
      // manufactured from the profile row's differing pressure.
      final tanks = await tankSeriesFor(db, 'd-existing');
      expect(tanks, hasLength(1));
      expect(codec.decode(tanks.single['samples'] as dynamic), [
        const TankPressureSample(timestamp: 0, pressure: 200.0),
      ]);
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
          // FK parents the v182/v183 rungs' series tables need to exist at
          // all (_assertProfileSeriesSchema), same as a real database has
          // carried since long before v58. dive_data_sources needs its
          // pre-v66 shape: the v66 rung rebuilds it and would otherwise fail
          // on a table this minimal.
          rawDb.execute(
            'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
          );
          createPreV66DiveDataSourcesTableRaw(rawDb);
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
              computer_id TEXT,
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

          createV71MediaTableRaw(rawDb);
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      await db.customSelect('SELECT 1').get();

      final tanks = await tankSeriesFor(db, 'd-multi');
      expect(tanks, hasLength(1));
      // Should be assigned to the first tank by rowid
      expect(tanks.single['tank_id'], 'first-tank');
    });
  });
}
