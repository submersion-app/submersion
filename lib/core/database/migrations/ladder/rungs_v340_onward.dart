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
    // v340: a combined dive's water temperature, CNS at the end and OTU
    // describe the whole dive again rather than its first segment (issue
    // #4136). Data only, so the compatibility floor does not move.
    if (from < 340) await repairCombinedDiveSummaries(this);
    if (from < 340) await reportProgress();

    // v341: dive_plan_series, a saved repetitive dive series, and the
    // dive_plans / dive_plan_tanks columns that place a plan in one (issue
    // #3565). Table and columns only, no backfill: a plan with no series is
    // a one-dive series. Re-asserted in beforeOpen. Renumbered from 339 and
    // then 340, which upstream claimed first for issues #3361 and #4136.
    if (from < 341) {
      await _assertDivePlanSeriesTable();
      await _assertDivePlanSeriesColumns();
    }
    if (from < 341) await reportProgress();

    // v342: dive_plans.fixed_start, whether a planned dive's start was set by
    // the diver rather than following from its surface interval, and
    // dive_plans.setting_overrides, the setting groups a dive keeps its own
    // values for (issue #3565, phase 2). Defaulted, no backfill. Re-asserted
    // in beforeOpen.
    if (from < 342) await _assertDivePlanPhase2Columns();
    if (from < 342) await reportProgress();

    // v346: an item's last service date is its newest service record's
    // again where logging an older record had moved it back (issue #4201).
    // Data only, so the compatibility floor does not move. Numbered past
    // 343, which three open PRs claim, so they can take 343 to 345.
    if (from < 346) await _repairLastServiceDates();
    if (from < 346) await reportProgress();
  }
}
