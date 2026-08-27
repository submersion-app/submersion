import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/course_templates.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

void main() {
  group('CourseTemplateCatalog', () {
    test('has unique template ids and non-empty requirement lists', () {
      final ids = CourseTemplateCatalog.templates.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final template in CourseTemplateCatalog.templates) {
        expect(
          template.requirements,
          isNotEmpty,
          reason: '${template.id} has no requirements',
        );
        for (final req in template.requirements) {
          expect(req.name.trim(), isNotEmpty);
          expect(req.targetCount, greaterThanOrEqualTo(1));
        }
      }
    });

    test('AOW template models five adventure dives plus knowledge', () {
      final aow = CourseTemplateCatalog.templates.firstWhere(
        (t) => t.id == 'advanced-open-water',
      );
      final diveTotal = aow.requirements
          .where((r) => r.kind == RequirementKind.dive)
          .fold<int>(0, (sum, r) => sum + r.targetCount);
      expect(diveTotal, 5);
      expect(
        aow.requirements.any((r) => r.kind == RequirementKind.checklist),
        isTrue,
      );
    });
  });
}
