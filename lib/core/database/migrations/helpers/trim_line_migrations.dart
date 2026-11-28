part of '../app_database_migrations.dart';

/// The default visibility and the palette colour of the trim line on the dive
/// profile (v394, issue #5098).
extension TrimLineMigrations on AppDatabase {
  /// The two `diver_settings` columns (v394, issue #5098): visibility
  /// defaulted off, colour null (the metric's default). No backfill. Safe
  /// from both the v394 rung and the beforeOpen backstop.
  Future<void> _assertTrimLineColumns() async {
    // The CHECK matches the constraint Drift gives a fresh install's boolean
    // column, so an upgraded database has the same schema.
    await _addColumnIfMissing(
      'diver_settings',
      'default_show_trim',
      'INTEGER NOT NULL DEFAULT 0 CHECK (default_show_trim IN (0, 1))',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'profile_color_trim',
      'INTEGER',
    );
  }
}
