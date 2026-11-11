part of '../app_database_migrations.dart';

/// Whether dive details pins a thin, scrubbable profile strip once the
/// profile card scrolls away (issue #4423). On for every diver, existing ones
/// included: the column is new, so no saved choice is overwritten.
extension PinnedProfileMigrations on AppDatabase {
  /// v359: diver_settings.pin_profile_on_scroll. Idempotent; called from the
  /// rung and the beforeOpen backstop.
  Future<void> _assertPinProfileOnScrollColumn() async {
    await _addColumnIfMissing(
      'diver_settings',
      'pin_profile_on_scroll',
      'INTEGER NOT NULL DEFAULT 1 CHECK (pin_profile_on_scroll IN (0, 1))',
    );
  }
}
