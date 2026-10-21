part of '../app_database_migrations.dart';

/// v308: reserve pressure and gradient factors join the live-resolve group
/// (issue #3552, follow-up to v304-307). Both were previously
/// snapshot-on-create - gfLow/gfHigh already had a diver Settings default
/// ([gfLowProvider]/[gfHighProvider], copied onto a plan only at creation),
/// reservePressure had none at all (hardcoded to the pressure unit's
/// convention, 50 bar / 500 psi, with no Settings override). Both now
/// resolve live like every other Setup field: a plan's own value wins,
/// else the diver's Settings. Renumbered from 306 as #3482 shipped 302-303
/// first.
extension ReservePressureGfMigrations on AppDatabase {
  /// Drops NOT NULL from dive_plans.reserve_pressure/gf_low/gf_high. Same
  /// table-rebuild technique as [DivePlanMigrations._assertDivePlanSetupFieldsNullable]
  /// (v305) - see that helper's doc comment for why it is safe. A separate
  /// rung because these three were snapshot-on-create, not simply missing a
  /// column, until this issue's own cross-examination pass reconsidered them.
  Future<void> _assertDivePlanReserveAndGfNullable() async {
    const columns = {
      'reserve_pressure': 'REAL',
      'gf_low': 'INTEGER',
      'gf_high': 'INTEGER',
    };

    final stored = await customSelect(
      "SELECT sql FROM sqlite_master WHERE type = 'table' "
      "AND name = 'dive_plans'",
    ).get();
    if (stored.isEmpty) return; // minimal fixture database: table absent
    final createSql = stored.first.read<String>('sql');

    var rebuiltSql = createSql;
    var changed = false;
    for (final entry in columns.entries) {
      final clause = RegExp(
        '"${entry.key}"\\s+${entry.value}\\s+NOT\\s+NULL',
        caseSensitive: false,
      );
      if (!clause.hasMatch(rebuiltSql)) continue; // already nullable
      rebuiltSql = rebuiltSql.replaceFirst(
        clause,
        '"${entry.key}" ${entry.value}',
      );
      changed = true;
    }

    // diver_settings.planner_reserve_pressure is additive, independent of
    // whether dive_plans needed a rebuild. Backfilled only on the run that
    // actually adds the column: this runs from the beforeOpen backstop on
    // every open, and re-running the backfill on a later open would reset
    // a diver's own edit back to the pressure-unit convention.
    final hadReserveColumn = await _columnExists(
      'diver_settings',
      'planner_reserve_pressure',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_reserve_pressure',
      'REAL NOT NULL DEFAULT 50.0',
    );
    // Preserves the pre-migration default for an imperial diver (500 psi,
    // not a straight unit conversion of 50 bar) rather than silently
    // changing what an untouched plan resolves to. Guarded on pressure_unit
    // existing: a minimal migration-test fixture may have neither column.
    if (!hadReserveColumn &&
        await _columnExists('diver_settings', 'pressure_unit')) {
      await customStatement(
        "UPDATE diver_settings SET planner_reserve_pressure = 500.0 / 14.5038 "
        "WHERE pressure_unit = 'psi'",
      );
    }

    if (!changed) return; // every dive_plans column already migrated

    final header = RegExp(
      r'^CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"?dive_plans"?',
      caseSensitive: false,
    );
    if (!header.hasMatch(rebuiltSql)) {
      developer.log(
        'dive_plans reserve/GF columns: stored definition not in a '
        'recognised shape, nullability left unchanged',
        name: 'AppDatabase',
      );
      return;
    }
    const scratch = 'dive_plans_v308';
    rebuiltSql = rebuiltSql.replaceFirst(header, 'CREATE TABLE $scratch');
    final dependents = await customSelect(
      "SELECT sql FROM sqlite_master WHERE tbl_name = 'dive_plans' "
      "AND type IN ('index', 'trigger') AND sql IS NOT NULL",
    ).get();

    Future<bool> enforced() async =>
        (await customSelect(
          'PRAGMA foreign_keys',
        ).getSingle()).read<int>('foreign_keys') ==
        1;
    final wasEnforced = await enforced();
    if (wasEnforced) {
      await customStatement('PRAGMA foreign_keys = OFF');
      if (await enforced()) {
        developer.log(
          'dive_plans reserve/GF columns: foreign keys could not be '
          'switched off, rebuild deferred to a later open',
          name: 'AppDatabase',
        );
        return;
      }
    }
    try {
      await transaction(() async {
        await customStatement('DROP TABLE IF EXISTS $scratch');
        await customStatement(rebuiltSql);
        await customStatement('INSERT INTO $scratch SELECT * FROM dive_plans');
        await customStatement('DROP TABLE dive_plans');
        await customStatement('ALTER TABLE $scratch RENAME TO dive_plans');
        for (final row in dependents) {
          await customStatement(row.read<String>('sql'));
        }
      });
    } finally {
      if (wasEnforced) await customStatement('PRAGMA foreign_keys = ON');
    }
  }
}
