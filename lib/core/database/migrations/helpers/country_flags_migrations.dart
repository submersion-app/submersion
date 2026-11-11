part of '../app_database_migrations.dart';

/// The switch for the flags beside site locations and trips (v359, issue
/// #4426).
extension CountryFlagsMigrations on AppDatabase {
  /// `diver_settings.show_country_flags` (v359, issue #4426). Defaulted on,
  /// no backfill, so every existing diver keeps seeing flags. Safe from both
  /// the v359 rung and the beforeOpen backstop.
  Future<void> _assertShowCountryFlagsColumn() => _addColumnIfMissing(
    'diver_settings',
    'show_country_flags',
    // The CHECK matches the constraint Drift gives a fresh install's
    // boolean column, so an upgraded database has the same schema.
    'INTEGER NOT NULL DEFAULT 1 CHECK (show_country_flags IN (0, 1))',
  );
}
