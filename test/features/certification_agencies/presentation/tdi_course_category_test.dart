import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/presentation/tdi_course_category.dart';

void main() {
  group('tdiCourseCategoryOf', () {
    test('every level on TDI\'s ladder and specialties has a category', () {
      final levels = [
        ...CertificationLevelCatalog.ladderFor(CertificationAgency.tdi),
        ...CertificationLevelCatalog.specialtiesFor(CertificationAgency.tdi),
      ];
      for (final level in levels) {
        expect(
          tdiCourseCategoryOf(level),
          isNotNull,
          reason: '${level.name} has no TDI course category',
        );
      }
    });

    test('a level from another agency has no TDI category', () {
      expect(tdiCourseCategoryOf(CertificationLevel.openWater), isNull);
      expect(tdiCourseCategoryOf(CertificationLevel.gueFundamentals), isNull);
      // The old generic value TDI used to share with IANTD/PSAI: no
      // category, so the legacy fallback never gets a TDI header either.
      expect(tdiCourseCategoryOf(CertificationLevel.cave), isNull);
    });

    test('categorizes a representative course from each category', () {
      expect(
        tdiCourseCategoryOf(CertificationLevel.tdiTrimixDiver),
        TdiCourseCategory.openCircuit,
      );
      expect(
        tdiCourseCategoryOf(CertificationLevel.tdiAirDiluentCcrDiver),
        TdiCourseCategory.rebreather,
      );
      expect(
        tdiCourseCategoryOf(CertificationLevel.tdiO2ServiceTechnician),
        TdiCourseCategory.service,
      );
      expect(
        tdiCourseCategoryOf(CertificationLevel.tdiFullCaveDiver),
        TdiCourseCategory.overhead,
      );
      expect(
        tdiCourseCategoryOf(CertificationLevel.tdiInstructor),
        TdiCourseCategory.professional,
      );
    });
  });
}
