import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/presentation/iart_course_category.dart';

void main() {
  group('iartCourseCategoryOf', () {
    test("every level on IART's ladder and specialties has a category", () {
      final levels = [
        ...CertificationLevelCatalog.ladderFor(CertificationAgency.iart),
        ...CertificationLevelCatalog.specialtiesFor(CertificationAgency.iart),
      ];
      for (final level in levels) {
        expect(
          iartCourseCategoryOf(level),
          isNotNull,
          reason: '${level.name} has no IART course category',
        );
      }
    });

    test('a level from another agency has no IART category', () {
      expect(iartCourseCategoryOf(CertificationLevel.openWater), isNull);
      expect(iartCourseCategoryOf(CertificationLevel.tdiFullCaveDiver), isNull);
    });

    test('categorizes a representative course from each category', () {
      expect(
        iartCourseCategoryOf(CertificationLevel.iartRecreationalTrimix),
        IartCourseCategory.openCircuit,
      );
      expect(
        iartCourseCategoryOf(CertificationLevel.iartRebreatherLevel1),
        IartCourseCategory.rebreather,
      );
      expect(
        iartCourseCategoryOf(CertificationLevel.iartGasBlender),
        IartCourseCategory.service,
      );
      expect(
        iartCourseCategoryOf(CertificationLevel.iartFullCave),
        IartCourseCategory.overhead,
      );
      expect(
        iartCourseCategoryOf(CertificationLevel.iartIdc),
        IartCourseCategory.professional,
      );
    });
  });
}
