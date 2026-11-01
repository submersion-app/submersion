part of '../app_database_migrations.dart';

/// Saved repetitive dive series (issue #3565, phase 3).
extension DivePlanSeriesMigrations on AppDatabase {
  /// Idempotent creation of the v333 `dive_plan_series` table. Its
  /// `dive_plans(series_id)` index is in the canonical performance set,
  /// which beforeOpen asserts on every open. Created even on a partial
  /// migration-test fixture that lacks `divers` or `dives`: `dive_plans`
  /// references this table, so without it nothing can write a plan there.
  /// Safe from both the v333 rung and the beforeOpen backstop.
  Future<void> _assertDivePlanSeriesTable() async {
    await Migrator(this).createTable(divePlanSeries);
  }

  /// The v333 columns that place a plan in a series and carry a tank over
  /// from the dive before. All nullable or defaulted, with no backfill: a
  /// plan with no series is a one-dive series. `source_tank_id` has no
  /// foreign key on purpose, since it names a logged dive's tank or a plan
  /// tank. Safe from both the v333 rung and the beforeOpen backstop.
  Future<void> _assertDivePlanSeriesColumns() async {
    await _addColumnIfMissing(
      'dive_plans',
      'series_id',
      'TEXT REFERENCES dive_plan_series(id)',
    );
    await _addColumnIfMissing('dive_plans', 'series_index', 'INTEGER');
    await _addColumnIfMissing('dive_plans', 'dive_name', 'TEXT');
    await _addColumnIfMissing(
      'dive_plans',
      'fixed_start',
      'INTEGER NOT NULL DEFAULT 0 CHECK (fixed_start IN (0, 1))',
    );
    await _addColumnIfMissing('dive_plans', 'setting_overrides', 'TEXT');
    await _addColumnIfMissing('dive_plan_tanks', 'source_tank_id', 'TEXT');
    await _addColumnIfMissing(
      'dive_plan_tanks',
      'start_pressure_pinned',
      'INTEGER NOT NULL DEFAULT 0 '
          'CHECK (start_pressure_pinned IN (0, 1))',
    );
  }
}
