part of '../app_database_migrations.dart';

/// The default visibility of the net buoyancy line on the dive profile (v370,
/// issue #4593).
extension BuoyancyLineMigrations on AppDatabase {
  /// `diver_settings.default_show_buoyancy` (v370, issue #4593). Defaulted
  /// off, no backfill. Safe from both the v370 rung and the beforeOpen
  /// backstop.
  Future<void> _assertDefaultShowBuoyancyColumn() => _addColumnIfMissing(
    'diver_settings',
    'default_show_buoyancy',
    // The CHECK matches the constraint Drift gives a fresh install's boolean
    // column, so an upgraded database has the same schema.
    'INTEGER NOT NULL DEFAULT 0 CHECK (default_show_buoyancy IN (0, 1))',
  );
}
