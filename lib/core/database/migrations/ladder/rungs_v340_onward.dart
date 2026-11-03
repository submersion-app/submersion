part of '../app_database_migrations.dart';

/// The rungs that take a database to schema version 340 and above.
///
/// New rungs are appended here. When this file nears 800 lines, give
/// it a closed range like its neighbours and start the next one.
///
/// A rung that rewrites stored values in place (not one that only adds
/// columns or copies them) lists the column in `changeLogRewrittenColumns`,
/// so a revert will not put back a value from before the rewrite.
extension RungsFromV340 on AppDatabase {
  Future<void> _rungsFromV340(
    Migrator m,
    int from,
    Future<void> Function() reportProgress,
  ) async {
    // v340: dive_plan_series, a saved repetitive dive series, and the
    // dive_plans / dive_plan_tanks columns that place a plan in one (issue
    // #3565). Table and columns only, no backfill: a plan with no series is
    // a one-dive series. Re-asserted in beforeOpen. Renumbered from 339,
    // which upstream claimed first for issue #3361.
    if (from < 340) {
      await _assertDivePlanSeriesTable();
      await _assertDivePlanSeriesColumns();
    }
    if (from < 340) await reportProgress();
  }
}
