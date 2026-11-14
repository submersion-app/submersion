part of '../app_database_migrations.dart';

/// The default visibility of the isobaric counterdiffusion overlay (v364,
/// issue #4530).
extension CounterdiffusionMigrations on AppDatabase {
  /// `diver_settings.default_show_counterdiffusion` (v364, issue #4530).
  /// Defaulted off, no backfill. Safe from both the v364 rung and the
  /// beforeOpen backstop.
  Future<void> _assertDefaultShowCounterdiffusionColumn() =>
      _addColumnIfMissing(
        'diver_settings',
        'default_show_counterdiffusion',
        // The CHECK matches the constraint Drift gives a fresh install's
        // boolean column, so an upgraded database has the same schema.
        'INTEGER NOT NULL DEFAULT 0 '
            'CHECK (default_show_counterdiffusion IN (0, 1))',
      );
}
