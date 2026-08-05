import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

CourseRequirement _req({
  RequirementKind kind = RequirementKind.dive,
  int targetCount = 1,
  DateTime? completedAt,
}) {
  return CourseRequirement(
    id: 'req-1',
    courseId: 'course-1',
    name: 'Deep adventure dive',
    kind: kind,
    targetCount: targetCount,
    completedAt: completedAt,
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

RequirementDiveSummary _dive(String id) => RequirementDiveSummary(
  linkId: 'link-$id',
  diveId: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 7, 1),
  siteName: 'Blue Hole',
);

void main() {
  group('RequirementKind.fromName', () {
    test('parses known names and defaults unknown to dive', () {
      expect(RequirementKind.fromName('checklist'), RequirementKind.checklist);
      expect(RequirementKind.fromName('dive'), RequirementKind.dive);
      expect(RequirementKind.fromName('garbage'), RequirementKind.dive);
      expect(RequirementKind.fromName(null), RequirementKind.dive);
    });
  });

  group('CourseRequirementProgress.isSatisfied', () {
    test('dive kind satisfied only at targetCount links', () {
      final p2of3 = CourseRequirementProgress(
        requirement: _req(targetCount: 3),
        linkedDives: [_dive('d1'), _dive('d2')],
      );
      expect(p2of3.creditCount, 2);
      expect(p2of3.isSatisfied, isFalse);

      final p3of3 = CourseRequirementProgress(
        requirement: _req(targetCount: 3),
        linkedDives: [_dive('d1'), _dive('d2'), _dive('d3')],
      );
      expect(p3of3.isSatisfied, isTrue);
    });

    test('checklist kind ignores links, satisfied by completedAt', () {
      final unchecked = CourseRequirementProgress(
        requirement: _req(kind: RequirementKind.checklist),
        linkedDives: [_dive('d1')],
      );
      expect(unchecked.isSatisfied, isFalse);

      final checked = CourseRequirementProgress(
        requirement: _req(
          kind: RequirementKind.checklist,
          completedAt: DateTime(2026, 7, 1),
        ),
        linkedDives: const [],
      );
      expect(checked.isSatisfied, isTrue);
    });
  });

  group('CourseProgress', () {
    test('rolls up satisfied counts; empty course is not complete', () {
      final progress = CourseProgress(
        courseId: 'course-1',
        requirements: [
          CourseRequirementProgress(
            requirement: _req(),
            linkedDives: [_dive('d1')],
          ),
          CourseRequirementProgress(
            requirement: _req(kind: RequirementKind.checklist),
            linkedDives: const [],
          ),
        ],
      );
      expect(progress.satisfiedCount, 1);
      expect(progress.totalCount, 2);
      expect(progress.isComplete, isFalse);

      const empty = CourseProgress(courseId: 'course-1', requirements: []);
      expect(empty.isComplete, isFalse);
    });
  });

  group('CourseRequirement copyWith', () {
    test('copyWith preserves and clearCompletedAt clears', () {
      final req = _req(
        kind: RequirementKind.checklist,
        completedAt: DateTime(2026, 7, 1),
      );
      final renamed = req.copyWith(name: 'Knowledge development');
      expect(renamed.name, 'Knowledge development');
      expect(renamed.completedAt, req.completedAt);

      final cleared = req.clearCompletedAt();
      expect(cleared.completedAt, isNull);
      expect(cleared.name, req.name);
    });
  });
}
