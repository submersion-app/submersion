part of '../app_database_migrations.dart';

/// Dive computer download connections (v279, issue #3106).
extension DiveComputerConnectionMigrations on AppDatabase {
  /// Idempotent creation of `dive_computer_connections`. Its index is in the
  /// canonical performance set, which beforeOpen asserts on every open.
  /// Skipped on a partial fixture without `dive_computers`, so its foreign
  /// key never points nowhere. Safe from both the v279 rung and the
  /// beforeOpen backstop.
  Future<void> _assertDiveComputerConnectionSchema() async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: const [Variable<String>('dive_computers')],
    ).get();
    if (rows.isEmpty) return;
    await Migrator(this).createTable(diveComputerConnections);
  }
}
