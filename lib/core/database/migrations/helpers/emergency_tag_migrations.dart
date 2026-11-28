part of '../app_database_migrations.dart';

/// The emergency tag column (v395, issue #5060).
extension EmergencyTagMigrations on AppDatabase {
  /// `divers.emergency_tag_share`, nullable JSON. No backfill. Safe from
  /// both the v395 rung and the beforeOpen backstop.
  Future<void> _assertEmergencyTagColumn() =>
      _addColumnIfMissing('divers', 'emergency_tag_share', 'TEXT');
}
