part of '../app_database_migrations.dart';

/// What a derived course requirement counts (v385): the rebreather an hours-
/// on-CCR requirement is on, and the dive query a dive-query requirement
/// matches.
extension CourseRequirementMigrations on AppDatabase {
  /// The two nullable `course_requirements` columns. No backfill. Safe from
  /// both the v385 rung and the beforeOpen backstop.
  Future<void> _assertCourseRequirementConditionColumns() async {
    await _addColumnIfMissing('course_requirements', 'equipment_id', 'TEXT');
    await _addColumnIfMissing('course_requirements', 'query_json', 'TEXT');
  }
}
