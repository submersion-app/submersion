part of '../app_database_migrations.dart';

/// Readings from Apple Health on a dive (issue #637).
extension DiveHealthMigrations on AppDatabase {
  /// Idempotent creation of the v354 `dive_health_records` table, safe from
  /// both the v354 rung and the beforeOpen backstop.
  Future<void> _assertDiveHealthRecordsTable() async {
    await Migrator(this).createTable(diveHealthRecords);
  }
}
