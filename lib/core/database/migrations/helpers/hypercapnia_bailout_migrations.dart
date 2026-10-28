part of '../app_database_migrations.dart';

/// Hypercapnia-bailout phase for CCR/SCR open-circuit bailout (issue #3743):
/// an elevated RMV for a configurable duration at the start of a bailout,
/// layered over the existing stressed-SAC fallback. Off by default; no
/// existing diver's bailout sizing changes until they turn it on.
extension HypercapniaBailoutMigrations on AppDatabase {
  /// v322: diver_settings gains the hypercapnia toggle/factor/duration;
  /// dive_plans gains the matching per-plan overrides and "explicitly off"
  /// flag (null/false = follow the diver's Settings, matching
  /// `ppo2_deco_bands_explicitly_off`'s shape). Idempotent; called from the
  /// rung and the beforeOpen backstop.
  Future<void> _assertHypercapniaBailoutColumns() async {
    await _addColumnIfMissing(
      'diver_settings',
      'planner_hypercapnia_enabled',
      'INTEGER NOT NULL DEFAULT 0 CHECK (planner_hypercapnia_enabled IN (0, 1))',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_hypercapnia_factor',
      'REAL NOT NULL DEFAULT 4.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'planner_hypercapnia_minutes',
      'INTEGER NOT NULL DEFAULT 5',
    );
    await _addColumnIfMissing('dive_plans', 'hypercapnia_amv', 'REAL');
    await _addColumnIfMissing('dive_plans', 'hypercapnia_minutes', 'INTEGER');
    await _addColumnIfMissing(
      'dive_plans',
      'hypercapnia_explicitly_off',
      'INTEGER NOT NULL DEFAULT 0 CHECK (hypercapnia_explicitly_off IN (0, 1))',
    );
  }
}
