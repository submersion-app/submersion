part of '../app_database_migrations.dart';

/// Media held back from older devices (issue #5122).
extension HeldMediaMigrations on AppDatabase {
  /// v394: the device-local held_media table. Idempotent.
  Future<void> _assertHeldMediaSchema() async {
    if (!await _tableExists('held_media')) {
      await Migrator(this).createTable(heldMedia);
    }
  }
}
