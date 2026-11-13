part of '../app_database_migrations.dart';

/// The computed deco verdicts the `deco` query field reads (issue #4461).
extension DecoStatusMigrations on AppDatabase {
  /// v362: the device-local deco verdict table. Idempotent; skipped on a
  /// partial fixture with no dives table to reference.
  Future<void> _assertDiveDecoStatusTable() async {
    if (!await _tableExists('dives')) return;
    await Migrator(this).createTable(diveDecoStatus);
  }
}
