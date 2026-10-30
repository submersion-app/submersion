part of '../app_database_migrations.dart';

/// Global defaults and the explicit-off override for air breaks and the
/// turn-pressure rule (issue #3552, follow-up to v304-306): both have no
/// sensible non-null default, so the new diver_settings columns stay
/// nullable (null = no policy/no rule, matching today) and a plan needs an
/// explicit "off" of its own to turn tracking off once the diver has opted
/// into a non-null default.
extension AirBreaksTurnPressureMigrations on AppDatabase {
  /// v307: diver_settings gains the air-break and turn-pressure defaults;
  /// dive_plans gains the explicit air-breaks-off override (turn-pressure's
  /// explicit off is `TurnPressureRule.off`, an enum value, not a column).
  /// Idempotent; called from the rung and the beforeOpen backstop.
  /// Renumbered from 305 as #3482 shipped 302-303 first.
  Future<void> _assertAirBreaksTurnPressureDefaultColumns() async {
    await _addColumnIfMissing(
      'diver_settings',
      'planner_turn_pressure_rule',
      'TEXT',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_turn_pressure_fraction',
      'REAL',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_air_break_o2_seconds',
      'INTEGER',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_air_break_break_seconds',
      'INTEGER',
    );
    await _addColumnIfMissing(
      'dive_plans',
      'air_breaks_explicitly_off',
      'INTEGER NOT NULL DEFAULT 0 CHECK (air_breaks_explicitly_off IN (0, 1))',
    );
  }
}
