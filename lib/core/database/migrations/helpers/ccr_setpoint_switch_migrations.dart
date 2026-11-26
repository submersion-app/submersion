part of '../app_database_migrations.dart';

/// The diver-wide CCR setpoint switch depth and a plan's no-switch flag (v384,
/// issue #3793).
extension CcrSetpointSwitchMigrations on AppDatabase {
  /// `diver_settings.ccr_setpoint_switch_depth` (REAL, default 10 m) and
  /// `dive_plans.setpoint_switch_off` (boolean, default off). No backfill: an
  /// existing diver gets the 10 m the planner always used, an existing plan
  /// keeps switching. Safe from both the v384 rung and the beforeOpen
  /// backstop.
  Future<void> _assertCcrSetpointSwitchColumns() async {
    await _addColumnIfMissing(
      'diver_settings',
      'ccr_setpoint_switch_depth',
      'REAL NOT NULL DEFAULT 10.0',
    );
    // The CHECK matches the constraint Drift gives a fresh install's
    // boolean column, so an upgraded database has the same schema.
    await _addColumnIfMissing(
      'dive_plans',
      'setpoint_switch_off',
      'INTEGER NOT NULL DEFAULT 0 CHECK (setpoint_switch_off IN (0, 1))',
    );
  }
}
