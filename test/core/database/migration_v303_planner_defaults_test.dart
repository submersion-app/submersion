import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v303: dive_plans Setup-accordion columns that were created NOT
/// NULL in the initial schema (not added later via ALTER TABLE ADD COLUMN)
/// drop that constraint via a table rebuild, so a plan can store "unset,
/// follow Settings" (issue #3552).
void main() {
  // A representative slice of the real dive_plans CREATE TABLE: just the
  // columns this rung touches, plus the minimum every row needs. Column
  // clauses use the same "NOT NULL DEFAULT" shape Drift's own generator
  // emits for a `real()/integer().withDefault(...)` column.
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      // Starts with CREATE TABLE at column 0, no leading whitespace: the
      // rebuild helper's header regex anchors on the start of the stored
      // SQL text, matching what Drift's own generator actually emits (it
      // never indents the statement), not an artificially pretty-printed
      // one.
      rawDb.execute(
        'CREATE TABLE dive_plans ("id" TEXT NOT NULL PRIMARY KEY, '
        '"name" TEXT NOT NULL, "gf_low" INTEGER NOT NULL, '
        '"gf_high" INTEGER NOT NULL, '
        '"descent_rate" REAL NOT NULL DEFAULT 18.0, '
        '"ascent_rate" REAL NOT NULL DEFAULT 9.0, '
        '"intermediate_ascent_rate" REAL NOT NULL DEFAULT 6.0, '
        '"shallow_ascent_rate" REAL NOT NULL DEFAULT 3.0, '
        '"final_ascent_rate" REAL NOT NULL DEFAULT 1.0, '
        '"last_stop_depth" REAL NOT NULL DEFAULT 3.0, '
        '"gas_switch_stop_seconds" INTEGER NOT NULL DEFAULT 0, '
        '"sac_bottom" REAL NOT NULL DEFAULT 15.0, '
        '"sac_factor" REAL NOT NULL DEFAULT 2.0, '
        '"problem_solving_minutes" INTEGER NOT NULL DEFAULT 2, '
        '"best_mix_end_meters" REAL NOT NULL DEFAULT 30.0, '
        '"deviation_depth_delta" REAL NOT NULL DEFAULT 5.0, '
        '"deviation_time_minutes" INTEGER NOT NULL DEFAULT 5, '
        '"created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO dive_plans (id, name, gf_low, gf_high, descent_rate, "
        'ascent_rate, intermediate_ascent_rate, shallow_ascent_rate, '
        'final_ascent_rate, last_stop_depth, gas_switch_stop_seconds, '
        'sac_bottom, sac_factor, problem_solving_minutes, '
        'best_mix_end_meters, deviation_depth_delta, '
        "deviation_time_minutes, created_at, updated_at) VALUES ('p1', "
        "'Rebuild plan', 30, 70, 20.0, 10.0, 7.0, 4.0, 2.0, 6.0, 30, 18.0, "
        '2.5, 3, 33.0, 6.0, 7, 0, 0)',
      );
    },
  );

  const columns = [
    'descent_rate',
    'ascent_rate',
    'intermediate_ascent_rate',
    'shallow_ascent_rate',
    'final_ascent_rate',
    'last_stop_depth',
    'gas_switch_stop_seconds',
    'sac_bottom',
    'sac_factor',
    'problem_solving_minutes',
    'best_mix_end_meters',
    'deviation_depth_delta',
    'deviation_time_minutes',
  ];

  test('v303 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(303));
    expect(AppDatabase.migrationVersions, contains(303));
    expect(
      AppDatabase.migrationStepCount(302),
      AppDatabase.migrationStepCount(303) + 1,
    );
  });

  test('the columns are additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(303));
  });

  test(
    'upgrading from v302 keeps the row\'s existing values unchanged',
    () async {
      final db = AppDatabase(dbAt(302));
      addTearDown(db.close);
      final row = await db
          .customSelect(
            'SELECT ${columns.join(", ")} FROM dive_plans WHERE id = ?',
            variables: [const Variable('p1')],
          )
          .getSingle();
      expect(row.read<double>('descent_rate'), 20.0);
      expect(row.read<double>('ascent_rate'), 10.0);
      expect(row.read<int>('gas_switch_stop_seconds'), 30);
      expect(row.read<double>('sac_bottom'), 18.0);
      expect(row.read<int>('problem_solving_minutes'), 3);
      expect(row.read<double>('deviation_depth_delta'), 6.0);
      expect(row.read<int>('deviation_time_minutes'), 7);
    },
  );

  test(
    'upgrading from v302 lets every rebuilt column accept an explicit NULL',
    () async {
      final db = AppDatabase(dbAt(302));
      addTearDown(db.close);
      // Before the rebuild these columns were NOT NULL: writing an explicit
      // NULL would have thrown a SQL constraint violation.
      await db.customStatement(
        'UPDATE dive_plans SET ${columns.map((c) => '$c = NULL').join(", ")} '
        "WHERE id = 'p1'",
      );
      final row = await db
          .customSelect(
            'SELECT ${columns.join(", ")} FROM dive_plans WHERE id = ?',
            variables: [const Variable('p1')],
          )
          .getSingle();
      for (final column in columns) {
        expect(row.data[column], isNull, reason: column);
      }
    },
  );

  test('beforeOpen heals a database already at v303 that lacks it', () async {
    final db = AppDatabase(dbAt(303));
    addTearDown(db.close);
    // Simulates a database that reached v303 without the rung (parallel
    // sync-adopt branch): the column is still NOT NULL until beforeOpen's
    // backstop runs, which this constructor already triggered.
    await db.customStatement(
      "UPDATE dive_plans SET descent_rate = NULL WHERE id = 'p1'",
    );
    final row = await db
        .customSelect("SELECT descent_rate FROM dive_plans WHERE id = 'p1'")
        .getSingle();
    expect(row.read<double?>('descent_rate'), isNull);
  });
}
