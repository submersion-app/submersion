part of '../app_database_migrations.dart';

/// The Explore derived metrics (issue #2195).
extension DerivedMetricsMigrations on AppDatabase {
  /// v247: the device-local derived metrics table. Idempotent; skipped on a
  /// partial fixture with no dives table to reference.
  Future<void> _assertDerivedMetricsTable() async {
    if (!await _tableExists('dives')) return;
    await Migrator(this).createTable(diveDerivedMetricsRows);
  }
}
