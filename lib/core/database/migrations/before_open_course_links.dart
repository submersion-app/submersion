part of 'app_database_migrations.dart';

/// beforeOpen backstop for the v288 course links (issue #2515), split out of
/// before_open.dart to keep it under the migration file size limit. The seed
/// only adds rows that `dives.course_id` names, so it cannot resurrect a
/// removed link.
extension BeforeOpenCourseLinks on AppDatabase {
  Future<void> _assertCourseLinks() async {
    await _assertDiveCourseSchema();
    await seedDiveCourseLinks(this);
  }
}
