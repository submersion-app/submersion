part of '../app_database_migrations.dart';

/// Dive computer auto-download opt-out (v333, issue #3361).
extension DiveComputerAutoDownloadMigrations on AppDatabase {
  /// `dive_computers.auto_download_disabled` (v333, issue #3361). Safe from
  /// both the v333 rung and the beforeOpen backstop.
  Future<void> _assertDiveComputerAutoDownloadDisabledColumn() =>
      _addColumnIfMissing(
        'dive_computers',
        'auto_download_disabled',
        'INTEGER NOT NULL DEFAULT 0',
      );
}
