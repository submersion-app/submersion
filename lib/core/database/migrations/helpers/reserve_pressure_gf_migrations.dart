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
  /// Drops NOT NULL from dive_plans.reserve_pressure/gf_low/gf_high, through
  /// the v305 helper, whose column set already includes them (so an upgrade
  /// across both rungs rebuilds dive_plans once), and adds the diver's
  /// reserve-pressure default. A separate rung because these three were
  /// snapshot-on-create, not simply missing a column, until this issue's
  /// own cross-examination pass reconsidered them.
  Future<void> _assertDivePlanReserveAndGfNullable() async {
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

    await _assertDivePlanSetupFieldsNullable();
  }
}
