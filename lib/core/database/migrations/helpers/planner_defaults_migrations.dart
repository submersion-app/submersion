part of '../app_database_migrations.dart';

/// The planner Setup-accordion global defaults on diver_settings.
extension PlannerDefaultsMigrations on AppDatabase {
  /// v304: diver_settings gains the global defaults for every Setup
  /// accordion field that had no app-wide source before (issue #3552):
  /// Deco rates, Gas/SAC, Contingency, and the two DPV team policy values.
  /// Idempotent; called from the rung and the beforeOpen backstop. Existing
  /// rows get the documented default, matching each field's old hardcoded
  /// `DivePlan`/`DpvMission` constructor default, so nothing changes for an
  /// existing diver until they edit a Setting. Renumbered from 302 as
  /// #3482 shipped 302-303 first.
  Future<void> _assertPlannerDefaultColumns() async {
    await _addColumnIfMissing(
      'diver_settings',
      'planner_descent_rate',
      'REAL NOT NULL DEFAULT 18.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_ascent_rate',
      'REAL NOT NULL DEFAULT 9.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_intermediate_ascent_rate',
      'REAL NOT NULL DEFAULT 6.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_shallow_ascent_rate',
      'REAL NOT NULL DEFAULT 3.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_final_ascent_rate',
      'REAL NOT NULL DEFAULT 1.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_gas_switch_stop_seconds',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_sac_bottom',
      'REAL NOT NULL DEFAULT 15.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_sac_deco',
      'REAL NOT NULL DEFAULT 15.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_sac_stressed_factor',
      'REAL NOT NULL DEFAULT 2.5',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_buddy_factor',
      'REAL NOT NULL DEFAULT 2.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_problem_solving_minutes',
      'INTEGER NOT NULL DEFAULT 2',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_best_mix_end_meters',
      'REAL NOT NULL DEFAULT 30.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_deviation_depth_delta',
      'REAL NOT NULL DEFAULT 5.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_deviation_time_minutes',
      'INTEGER NOT NULL DEFAULT 5',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_battery_reserve_fraction',
      'REAL NOT NULL DEFAULT 0.3333333333333333',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_walk_speed_mps',
      'REAL NOT NULL DEFAULT 0.8',
    );
  }
}
