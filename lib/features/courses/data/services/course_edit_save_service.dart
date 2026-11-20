import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';

/// Writes a course page's editing sitting (issue #4527, phase 3): its
/// changed values and every held write, in one transaction and one History
/// entry labelled with the cards it changed.
class CourseEditSaveService {
  CourseEditSaveService(this._courses);

  final CourseRepository _courses;

  /// Saves [apply] onto course [courseId] as stored now, so a value changed
  /// underneath on a card the diver never touched is kept. The update also
  /// rewrites the representative course of each dive assigned to it, inside
  /// the sitting. [alsoWrite] makes the held writes (requirements, credited
  /// dives, earned certifications, documents) after the row; with
  /// [alsoWriteIsAChange] they are written even when the row is unchanged.
  /// Returns the course before and after, or null when nothing changed.
  /// Throws [StateError] when it no longer exists.
  Future<({Course before, Course after})?> save({
    required String courseId,
    required Course Function(Course stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) => writeRecordSitting<Course>(
    table: 'courses',
    recordId: courseId,
    changedCardIds: changedCardIds,
    read: () => _courses.getCourseById(courseId),
    apply: apply,
    write: (_, merged) => _courses.updateCourse(merged),
    alsoWrite: alsoWrite,
    alsoWriteIsAChange: alsoWriteIsAChange,
  );

  /// Creates [course], a new course's sitting (issue #4527, phase 3, plan
  /// 11), keeping its id: the row, then [alsoWrite], the sitting's held
  /// writes (earned certifications, which can move a certification off
  /// another course, documents), in one transaction and one History entry
  /// naming [changedCardIds]. If any of them throws nothing is left.
  /// Throws [StateError] when [course] has no id, or one a stored course
  /// has.
  Future<Course> create({
    required Course course,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) => createRecordSitting<Course>(
    table: 'courses',
    recordId: course.id,
    changedCardIds: changedCardIds,
    isStored: () async => await _courses.getCourseById(course.id) != null,
    insert: () => _courses.createCourse(course),
    alsoWrite: alsoWrite,
    readBack: () => _courses.getCourseById(course.id),
    created: course,
  );
}

final courseEditSaveServiceProvider = Provider<CourseEditSaveService>(
  (ref) => CourseEditSaveService(ref.watch(courseRepositoryProvider)),
);
