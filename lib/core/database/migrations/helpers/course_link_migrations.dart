part of '../app_database_migrations.dart';

/// The `dive_courses` junction (v288, issue #2515).
extension CourseLinkMigrations on AppDatabase {
  /// Schema only: the table and its unique index. Idempotent.
  Future<void> _assertDiveCourseSchema() async {
    for (final parent in const ['dives', 'courses']) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(diveCourses);
    await assertDiveCourseUniqueness(this);
  }
}
