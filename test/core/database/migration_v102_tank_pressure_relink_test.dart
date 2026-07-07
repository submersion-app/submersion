import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v102 re-links tank_pressure_profiles rows that were stranded under a stale
/// tank id (issue #510). See `AppDatabase._relinkStrandedTankPressures`.
void main() {
  // Minimal pre-v102 shape for the three tables the migration touches. No FK
  // constraints so the test can insert an orphaned pressure row directly (the
  // real DB reaches this state via reparse/consolidation with FKs relaxed).
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
          'SELECT DISTINCT tank_id FROM tank_pressure_profiles '
          "WHERE dive_id = '$diveId' ORDER BY tank_id",
        )
        .get();
    return rows.map((r) => r.read<String>('tank_id')).toList();
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

      final earlyTarget = await db
          .customSelect(
            "SELECT DISTINCT tank_id FROM tank_pressure_profiles "
            "WHERE dive_id = 'd3' AND id IN ('b1', 'b2')",
          )
          .getSingle();
      final lateTarget = await db
          .customSelect(
            "SELECT DISTINCT tank_id FROM tank_pressure_profiles "
            "WHERE dive_id = 'd3' AND id IN ('a1', 'a2')",
          )
          .getSingle();

      expect(earlyTarget.read<String>('tank_id'), 'tank-1');
      expect(lateTarget.read<String>('tank_id'), 'tank-2');
    },
  );

  test('a second repair run over healed data is a no-op', () async {
    // Seed an orphaned series so the migration re-links it on open, then run
    // the repair AGAIN and confirm nothing else moves and no rows are lost.
    final db = AppDatabase(
      makeDb((rawDb) {
        rawDb.execute("INSERT INTO dives VALUES ('d4', 1, 1, 1)");
        rawDb.execute("INSERT INTO dive_tanks VALUES ('tank-x', 'd4', 0)");
        rawDb.execute(
          "INSERT INTO tank_pressure_profiles VALUES "
          "('p1', 'd4', 'tank-old', 0, 200.0), "
          "('p2', 'd4', 'tank-old', 60, 150.0)",
        );
      }),
    );
    addTearDown(() => db.close());

    // First pass ran during the migration on open.
    expect(await pressureTankIds(db, 'd4'), ['tank-x']);
    final countBefore = await db
        .customSelect('SELECT COUNT(*) AS n FROM tank_pressure_profiles')
        .getSingle();

    // Explicit second pass must change nothing.
    await db.relinkStrandedTankPressuresForTest();

    expect(await pressureTankIds(db, 'd4'), ['tank-x']);
    final countAfter = await db
        .customSelect('SELECT COUNT(*) AS n FROM tank_pressure_profiles')
        .getSingle();
    expect(countAfter.read<int>('n'), countBefore.read<int>('n'));
  });

  test('v102 is registered in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(102));
    expect(AppDatabase.migrationVersions, contains(102));
  });
}
