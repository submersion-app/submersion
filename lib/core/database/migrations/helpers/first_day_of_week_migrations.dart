part of '../app_database_migrations.dart';

/// The diver's first day of the week (v343, issue #4232).
extension FirstDayOfWeekMigrations on AppDatabase {
  /// `diver_settings.first_day_of_week` (v343, issue #4232). Defaults every
  /// existing diver to 'auto', which follows the device's region. Safe from
  /// both the v343 rung and the beforeOpen backstop.
  Future<void> _assertFirstDayOfWeekColumn() => _addColumnIfMissing(
    'diver_settings',
    'first_day_of_week',
    "TEXT NOT NULL DEFAULT 'auto'",
  );
}
