part of '../app_database_migrations.dart';

/// The profile chart's Time only zoom choice (issue #5069).
extension ProfileZoomMigrations on AppDatabase {
  /// v389: diver_settings.profile_zoom_time_only (issue #5069), the profile
  /// chart's Time only zoom choice. Nullable with no default, like the v262
  /// viewport choice it pairs with, so null marks a row that has never held
  /// a value. Idempotent; called from the rung and the beforeOpen backstop.
  Future<void> _assertProfileZoomTimeOnlyColumn() async {
    await _addColumnIfMissing(
      'diver_settings',
      'profile_zoom_time_only',
      'INTEGER',
    );
  }
}
