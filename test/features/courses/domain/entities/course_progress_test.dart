import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

void main() {
  CourseRequirementProgress requirementCrediting(
    String id,
    List<String> diveIds,
  ) {
    final now = DateTime(2026);
    return CourseRequirementProgress(
      requirement: CourseRequirement(
        id: id,
        courseId: 'course-1',
        name: id,
        kind: RequirementKind.dive,
        createdAt: now,
        updatedAt: now,
      ),
      linkedDives: [
        for (final diveId in diveIds)
          RequirementDiveSummary(diveId: diveId, dateTime: now),
      ],
    );
  }

  test('creditedDiveIds gathers the dives of every requirement', () {
    final progress = CourseProgress(
      courseId: 'course-1',
      requirements: [
        requirementCrediting('deep', ['dive-1', 'dive-2']),
        requirementCrediting('night', ['dive-3']),
        requirementCrediting('navigation', []),
      ],
    );

    expect(progress.creditedDiveIds, {'dive-1', 'dive-2', 'dive-3'});
  });

  test('creditedDiveIds is empty for a course with no requirements', () {
    const progress = CourseProgress(courseId: 'course-1', requirements: []);

    expect(progress.creditedDiveIds, isEmpty);
  });
}
