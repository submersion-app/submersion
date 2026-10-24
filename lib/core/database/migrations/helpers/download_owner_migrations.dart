part of '../app_database_migrations.dart';

/// Whether a dive computer download defaults to the computer's owner (issue
/// #2050). On for every diver, existing ones included: the column is new, so
/// no saved choice is overwritten.
extension DownloadOwnerMigrations on AppDatabase {
  /// v310: diver_settings.downloads_follow_computer_owner. Idempotent; called
  /// from the rung and the beforeOpen backstop.
  Future<void> _assertDownloadOwnerColumn() async {
    await _addColumnIfMissing(
      'diver_settings',
      'downloads_follow_computer_owner',
      'INTEGER NOT NULL DEFAULT 1 '
          'CHECK (downloads_follow_computer_owner IN (0, 1))',
    );
  }
}
