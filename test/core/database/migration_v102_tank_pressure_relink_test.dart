import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

/// v102 re-links tank_pressure_profiles rows that were stranded under a stale
/// tank id (issue #510). See `AppDatabase._relinkStrandedTankPressures`.
///
/// v182/v183 (well past v102 in the same ladder) pack whatever
/// tank_pressure_profiles rows the repair leaves behind into
/// tank_pressure_series and drop the legacy table, so every assertion below
/// reads the packed series rather than the now-gone legacy table.
void main() {
  const codec = TankPressureSeriesCodec();

  // Minimal pre-v102 shape for the tables the migration touches. No FK
  // constraints so the test can insert an orphaned pressure row directly (the
  // real DB reaches this state via reparse/consolidation with FKs relaxed).
  // dive_computers is present only so _assertProfileSeriesSchema (v182/v183)
  // will create tank_pressure_series at all.
  NativeDatabase makeDb(void Function(dynamic rawDb) seed) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 101');
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            dive_date_time INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
        );
        rawDb.execute('''
          CREATE TABLE dive_tanks (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            tank_order INTEGER NOT NULL DEFAULT 0
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
        seed(rawDb);
      },
    );
  }

  Future<List<String>> pressureTankIds(AppDatabase db, String diveId) async {
    final rows = await db
        .customSelect(
          'SELECT DISTINCT tank_id FROM tank_pressure_series '
          "WHERE dive_id = '$diveId' ORDER BY tank_id",
        )
        .get();
    return rows.map((r) => r.read<String>('tank_id')).toList();
  }

  Future<List<TankPressureSample>> samplesFor(
    AppDatabase db,
    String diveId,
    String tankId,
  ) async {
    final row = await db
        .customSelect(
          'SELECT samples FROM tank_pressure_series '
          "WHERE dive_id = '$diveId' AND tank_id = '$tankId'",
        )
        .getSingle();
    return codec.decode(row.read('samples'));
  }

  test(
    're-links an orphaned single-tank pressure series to the current tank',
    () async {
      final db = AppDatabase(
        makeDb((rawDb) {
          rawDb.execute("INSERT INTO dives VALUES ('d1', 1, 1, 1)");
          // Current tank has a fresh UUID; pressure rows still carry the old id.
          rawDb.execute("INSERT INTO dive_tanks VALUES ('tank-new', 'd1', 0)");
          rawDb.execute(
            "INSERT INTO tank_pressure_profiles VALUES "
            "('p1', 'd1', 'tank-old', 0, 200.0), "
            "('p2', 'd1', 'tank-old', 60, 150.0)",
          );
        }),
      );
      addTearDown(() => db.close());

      // Touch the DB to run the migration.
      expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(102));

      expect(await pressureTankIds(db, 'd1'), ['tank-new']);
      expect(await samplesFor(db, 'd1', 'tank-new'), [
        const TankPressureSample(timestamp: 0, pressure: 200.0),
        const TankPressureSample(timestamp: 60, pressure: 150.0),
      ]);
    },
  );

  test('leaves correctly-keyed pressure untouched', () async {
    final db = AppDatabase(
      makeDb((rawDb) {
        rawDb.execute("INSERT INTO dives VALUES ('d2', 1, 1, 1)");
        rawDb.execute("INSERT INTO dive_tanks VALUES ('tank-a', 'd2', 0)");
        rawDb.execute(
          "INSERT INTO tank_pressure_profiles VALUES "
          "('p1', 'd2', 'tank-a', 0, 210.0), "
          "('p2', 'd2', 'tank-a', 60, 160.0)",
        );
      }),
    );
    addTearDown(() => db.close());

    expect(await pressureTankIds(db, 'd2'), ['tank-a']);
    expect(await samplesFor(db, 'd2', 'tank-a'), [
      const TankPressureSample(timestamp: 0, pressure: 210.0),
      const TankPressureSample(timestamp: 60, pressure: 160.0),
    ]);
  });

  test(
    'assigns multiple orphaned series to unmatched tanks by tank order',
    () async {
      final db = AppDatabase(
        makeDb((rawDb) {
          rawDb.execute("INSERT INTO dives VALUES ('d3', 1, 1, 1)");
          // Two current tanks, ordered.
          rawDb.execute("INSERT INTO dive_tanks VALUES ('tank-1', 'd3', 0)");
          rawDb.execute("INSERT INTO dive_tanks VALUES ('tank-2', 'd3', 1)");
          // Two orphaned series; 'old-early' starts first, so it maps to the
          // lowest-order unmatched tank (tank-1).
          rawDb.execute(
            "INSERT INTO tank_pressure_profiles VALUES "
            "('a1', 'd3', 'old-late', 100, 200.0), "
            "('a2', 'd3', 'old-late', 160, 150.0), "
            "('b1', 'd3', 'old-early', 0, 190.0), "
            "('b2', 'd3', 'old-early', 60, 140.0)",
          );
        }),
      );
      addTearDown(() => db.close());

      expect(await pressureTankIds(db, 'd3'), ['tank-1', 'tank-2']);
      expect(await samplesFor(db, 'd3', 'tank-1'), [
        const TankPressureSample(timestamp: 0, pressure: 190.0),
        const TankPressureSample(timestamp: 60, pressure: 140.0),
      ]);
      expect(await samplesFor(db, 'd3', 'tank-2'), [
        const TankPressureSample(timestamp: 100, pressure: 200.0),
        const TankPressureSample(timestamp: 160, pressure: 150.0),
      ]);
    },
  );

  // "a second repair run over healed data is a no-op" is deleted: the repair
  // helper (relinkStrandedTankPressuresForTest / _relinkStrandedTankPressures)
  // only ever operates on the legacy tank_pressure_profiles table, which
  // v183 drops once its own pack has run. Calling the helper again after
  // that point is a table-existence no-op regardless of whether the repair
  // logic itself is idempotent, so the test could no longer exercise what it
  // was written to check.

  test('v102 is registered in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(102));
    expect(AppDatabase.migrationVersions, contains(102));
  });
}
