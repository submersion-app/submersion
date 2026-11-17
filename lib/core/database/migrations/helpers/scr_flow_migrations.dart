part of '../app_database_migrations.dart';

/// The planner's semi-closed loop flow (v374, issue #4660): a plan's own SCR
/// injection rate, SCR VO2 and pSCR VO2, and the diver's defaults for them.
extension ScrFlowMigrations on AppDatabase {
  /// `dive_plans.scr_injection_rate`, `.scr_vo2` and `.pscr_vo2` (nullable:
  /// null follows the diver's default), and `diver_settings`'
  /// `planner_scr_injection_rate`, `planner_scr_vo2` and `planner_pscr_vo2`
  /// (defaulted to the figures every plan used before, surface L/min). No
  /// backfill. Safe from both the v374 rung and the beforeOpen backstop.
  Future<void> _assertScrFlowColumns() async {
    await _addColumnIfMissing('dive_plans', 'scr_injection_rate', 'REAL');
    await _addColumnIfMissing('dive_plans', 'scr_vo2', 'REAL');
    await _addColumnIfMissing('dive_plans', 'pscr_vo2', 'REAL');
    await _addColumnIfMissing(
      'diver_settings',
      'planner_scr_injection_rate',
      'REAL NOT NULL DEFAULT 12.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_scr_vo2',
      'REAL NOT NULL DEFAULT 1.3',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_pscr_vo2',
      'REAL NOT NULL DEFAULT 0.72',
    );
  }
}
