import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  test('isProfessionalLevel is true for exactly the professional ratings', () {
    const professionalLevels = {
      // Generic ladder
      CertificationLevel.diveGuide,
      CertificationLevel.diveMaster,
      CertificationLevel.assistantInstructor,
      CertificationLevel.instructor,
      CertificationLevel.masterInstructor,
      CertificationLevel.courseDirector,
      // CMAS
      CertificationLevel.cmas3StarDiverAssistantInstructor,
      CertificationLevel.cmas4StarDiverAssistantInstructor,
      CertificationLevel.cmas1StarInstructor,
      CertificationLevel.cmas2StarInstructor,
      CertificationLevel.cmas3StarInstructor,
      // BSAC
      CertificationLevel.bsacOpenWaterInstructor,
      CertificationLevel.bsacAdvancedInstructor,
      CertificationLevel.bsacNationalInstructor,
      // FFESSM cadre and teaching ratings
      CertificationLevel.ffessmN4,
      CertificationLevel.ffessmN5,
      CertificationLevel.ffessmInitiateur,
      CertificationLevel.ffessmE2,
      CertificationLevel.ffessmMf1,
      CertificationLevel.ffessmMf2,
      CertificationLevel.ffessmMoniteurNitroxConfirme,
      CertificationLevel.ffessmMoniteurTrimix,
      CertificationLevel.ffessmMoniteurRecycleurCcr,
      CertificationLevel.ffessmFormateurTiv,
      CertificationLevel.ffessmFormateurBio1,
      CertificationLevel.ffessmFormateurBio2,
      CertificationLevel.ffessmFormateurBio3,
      // ACUC
      CertificationLevel.acucUnderwaterGuide,
      CertificationLevel.acucTeachingAssistant,
      CertificationLevel.acucOpenWaterInstructor,
      CertificationLevel.acucAdvancedInstructor,
      CertificationLevel.acucInstructorTrainer,
      CertificationLevel.acucInstructorTrainerEvaluator,
      // DAN
      CertificationLevel.danInstructor,
      CertificationLevel.danInstructorTrainer,
      // TDI
      CertificationLevel.tdiTechnicalDivemaster,
      CertificationLevel.tdiNonDivingSpecialtyInstructor,
      CertificationLevel.tdiInstructor,
      CertificationLevel.tdiInstructorTrainer,
      // IART instructor track and dive guide
      CertificationLevel.iartIoc,
      CertificationLevel.iartItp,
      CertificationLevel.iartIe,
      CertificationLevel.iartIdc,
      CertificationLevel.iartDiveGuide,
    };
    for (final level in CertificationLevel.values) {
      expect(
        level.isProfessionalLevel,
        professionalLevels.contains(level),
        reason: '${level.name} isProfessionalLevel mismatch',
      );
    }
  });

  test('every instructor grade is also a professional rating', () {
    for (final level in CertificationLevel.values) {
      if (level.isInstructorLevel) {
        expect(level.isProfessionalLevel, isTrue, reason: level.name);
      }
    }
  });

  test('courses named for professionals are not professional ratings', () {
    // Holding DAN's first aid course for professionals, or a rescue or
    // leadership-adjacent diver grade, does not make the holder a pro.
    expect(CertificationLevel.danDfaPro.isProfessionalLevel, isFalse);
    expect(CertificationLevel.rescue.isProfessionalLevel, isFalse);
    expect(CertificationLevel.acucRescueLeader.isProfessionalLevel, isFalse);
    expect(CertificationLevel.bsacDiveLeader.isProfessionalLevel, isFalse);
    expect(CertificationLevel.masterDiver.isProfessionalLevel, isFalse);
  });
}
