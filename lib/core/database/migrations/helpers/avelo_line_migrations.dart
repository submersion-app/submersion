part of '../app_database_migrations.dart';

/// The default visibility and the palette colour of the three Avelo lines on
/// the dive profile (v379, issue #4664).
extension AveloLineMigrations on AppDatabase {
  /// The six `diver_settings` columns (v379, issue #4664): visibility
  /// defaulted off, colours null (the metric's default). No backfill. Safe
  /// from both the v379 rung and the beforeOpen backstop.
  Future<void> _assertAveloLineColumns() async {
    for (final column in const [
      'default_show_avelo_buoyancy',
      'default_show_avelo_gas_remaining',
      'default_show_computer_rmv',
    ]) {
      // The CHECK matches the constraint Drift gives a fresh install's
      // boolean column, so an upgraded database has the same schema.
      await _addColumnIfMissing(
        'diver_settings',
        column,
        'INTEGER NOT NULL DEFAULT 0 CHECK ($column IN (0, 1))',
      );
    }
    for (final column in const [
      'profile_color_avelo_buoyancy',
      'profile_color_avelo_gas_remaining',
      'profile_color_computer_rmv',
    ]) {
      await _addColumnIfMissing('diver_settings', column, 'INTEGER');
    }
  }
}
