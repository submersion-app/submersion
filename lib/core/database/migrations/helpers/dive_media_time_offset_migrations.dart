part of '../app_database_migrations.dart';

/// A dive's media time shift (v365, issue #4539).
extension DiveMediaTimeOffsetMigrations on AppDatabase {
  /// `dives.media_time_offset_seconds` (v365, issue #4539). Idempotent, so
  /// the ladder and the beforeOpen backstop can both call it.
  Future<void> _assertDiveMediaTimeOffsetColumn() => _addColumnIfMissing(
    'dives',
    'media_time_offset_seconds',
    'INTEGER NOT NULL DEFAULT 0',
  );
}
