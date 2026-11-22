part of '../app_database_migrations.dart';

/// The values a diver set by hand on a dive (v382, issue #4909).
extension DiveHandSetFieldsMigrations on AppDatabase {
  /// `dives.hand_set_fields` (v382). Nullable, no backfill: only edits saved
  /// after the update are marked. Idempotent, so the ladder and the
  /// beforeOpen backstop can both call it.
  Future<void> _assertDiveHandSetFieldsColumn() =>
      _addColumnIfMissing('dives', 'hand_set_fields', 'TEXT');
}
