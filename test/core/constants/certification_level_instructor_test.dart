import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  test('isInstructorLevel is true for exactly the instructor grades', () {
    const instructorLevels = {
      CertificationLevel.instructor,
      CertificationLevel.masterInstructor,
      CertificationLevel.courseDirector,
      CertificationLevel.cmas1StarInstructor,
      CertificationLevel.cmas2StarInstructor,
      CertificationLevel.cmas3StarInstructor,
      CertificationLevel.bsacOpenWaterInstructor,
      CertificationLevel.bsacAdvancedInstructor,
      CertificationLevel.bsacNationalInstructor,
    };
    for (final level in CertificationLevel.values) {
      expect(
        level.isInstructorLevel,
        instructorLevels.contains(level),
        reason: '${level.name} isInstructorLevel mismatch',
      );
    }
    // Assistant instructors cannot independently certify.
    expect(CertificationLevel.assistantInstructor.isInstructorLevel, isFalse);
    expect(
      CertificationLevel.cmas3StarDiverAssistantInstructor.isInstructorLevel,
      isFalse,
    );
  });

  test('diveGuide sits directly below diveMaster on every ladder that has '
      'diveMaster', () {
    for (final agency in [
      CertificationAgency.padi, // generic ladder
      CertificationAgency.ssi,
      CertificationAgency.naui,
      CertificationAgency.sdi,
      CertificationAgency.raid,
      null, // generic fallback
    ]) {
      final ladder = CertificationLevelCatalog.ladderFor(agency);
      final guideIdx = ladder.indexOf(CertificationLevel.diveGuide);
      final dmIdx = ladder.indexOf(CertificationLevel.diveMaster);
      expect(dmIdx, greaterThan(-1));
      expect(
        guideIdx,
        dmIdx - 1,
        reason:
            'diveGuide must rank immediately below diveMaster '
            'for agency $agency',
      );
    }
    // Ladders without diveMaster must NOT gain diveGuide.
    expect(
      CertificationLevelCatalog.ladderFor(CertificationAgency.gue),
      isNot(contains(CertificationLevel.diveGuide)),
    );
    expect(
      CertificationLevelCatalog.ladderFor(CertificationAgency.bsac),
      isNot(contains(CertificationLevel.diveGuide)),
    );
  });
}
