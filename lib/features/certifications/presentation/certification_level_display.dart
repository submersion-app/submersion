import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized name for a [CertificationLevel].
///
/// [CertificationLevel.displayName] stays hardcoded English on purpose: it
/// feeds data interchange (UDDF import/export, the field extractor, the PDF
/// templates) and the legacy derived-name matching in certification_title.dart.
/// This getter drives on-screen UI so the same values honor the active locale
/// (issue #1608).
///
/// Agency-specific proprietary grade names (BSAC, GUE, TDI Extended Range) are
/// kept in English in every locale, the same way the agency acronyms are.
///
/// The switch is exhaustive by enum value, so adding a value is a compile error
/// until its localization key is wired in.
extension CertificationLevelDisplay on CertificationLevel {
  String localizedName(AppLocalizations l10n) => switch (this) {
    CertificationLevel.openWater => l10n.enum_certificationLevel_openWater,
    CertificationLevel.advancedOpenWater =>
      l10n.enum_certificationLevel_advancedOpenWater,
    CertificationLevel.rescue => l10n.enum_certificationLevel_rescue,
    CertificationLevel.diveGuide => l10n.enum_certificationLevel_diveGuide,
    CertificationLevel.diveMaster => l10n.enum_certificationLevel_diveMaster,
    CertificationLevel.instructor => l10n.enum_certificationLevel_instructor,
    CertificationLevel.masterInstructor =>
      l10n.enum_certificationLevel_masterInstructor,
    CertificationLevel.courseDirector =>
      l10n.enum_certificationLevel_courseDirector,
    CertificationLevel.nitrox => l10n.enum_certificationLevel_nitrox,
    CertificationLevel.advancedNitrox =>
      l10n.enum_certificationLevel_advancedNitrox,
    CertificationLevel.decompression =>
      l10n.enum_certificationLevel_decompression,
    CertificationLevel.trimix => l10n.enum_certificationLevel_trimix,
    CertificationLevel.cavern => l10n.enum_certificationLevel_cavern,
    CertificationLevel.cave => l10n.enum_certificationLevel_cave,
    CertificationLevel.wreck => l10n.enum_certificationLevel_wreck,
    CertificationLevel.sidemount => l10n.enum_certificationLevel_sidemount,
    CertificationLevel.rebreather => l10n.enum_certificationLevel_rebreather,
    CertificationLevel.techDiver => l10n.enum_certificationLevel_techDiver,
    CertificationLevel.masterDiver => l10n.enum_certificationLevel_masterDiver,
    CertificationLevel.assistantInstructor =>
      l10n.enum_certificationLevel_assistantInstructor,
    CertificationLevel.extendedRange =>
      l10n.enum_certificationLevel_extendedRange,
    CertificationLevel.advancedTrimix =>
      l10n.enum_certificationLevel_advancedTrimix,
    CertificationLevel.cmas1StarDiver =>
      l10n.enum_certificationLevel_cmas1StarDiver,
    CertificationLevel.cmas2StarDiver =>
      l10n.enum_certificationLevel_cmas2StarDiver,
    CertificationLevel.cmas3StarDiver =>
      l10n.enum_certificationLevel_cmas3StarDiver,
    CertificationLevel.cmas4StarDiver =>
      l10n.enum_certificationLevel_cmas4StarDiver,
    CertificationLevel.cmas3StarDiverAssistantInstructor =>
      l10n.enum_certificationLevel_cmas3StarDiverAssistantInstructor,
    CertificationLevel.cmas4StarDiverAssistantInstructor =>
      l10n.enum_certificationLevel_cmas4StarDiverAssistantInstructor,
    CertificationLevel.cmas1StarInstructor =>
      l10n.enum_certificationLevel_cmas1StarInstructor,
    CertificationLevel.cmas2StarInstructor =>
      l10n.enum_certificationLevel_cmas2StarInstructor,
    CertificationLevel.cmas3StarInstructor =>
      l10n.enum_certificationLevel_cmas3StarInstructor,
    CertificationLevel.bsacOceanDiver =>
      l10n.enum_certificationLevel_bsacOceanDiver,
    CertificationLevel.bsacSportsDiver =>
      l10n.enum_certificationLevel_bsacSportsDiver,
    CertificationLevel.bsacDiveLeader =>
      l10n.enum_certificationLevel_bsacDiveLeader,
    CertificationLevel.bsacAdvancedDiver =>
      l10n.enum_certificationLevel_bsacAdvancedDiver,
    CertificationLevel.bsacFirstClassDiver =>
      l10n.enum_certificationLevel_bsacFirstClassDiver,
    CertificationLevel.bsacOpenWaterInstructor =>
      l10n.enum_certificationLevel_bsacOpenWaterInstructor,
    CertificationLevel.bsacAdvancedInstructor =>
      l10n.enum_certificationLevel_bsacAdvancedInstructor,
    CertificationLevel.bsacNationalInstructor =>
      l10n.enum_certificationLevel_bsacNationalInstructor,
    CertificationLevel.gueFundamentals =>
      l10n.enum_certificationLevel_gueFundamentals,
    CertificationLevel.gueRec1 => l10n.enum_certificationLevel_gueRec1,
    CertificationLevel.gueRec2 => l10n.enum_certificationLevel_gueRec2,
    CertificationLevel.gueRec3 => l10n.enum_certificationLevel_gueRec3,
    CertificationLevel.gueTech1 => l10n.enum_certificationLevel_gueTech1,
    CertificationLevel.gueTech2 => l10n.enum_certificationLevel_gueTech2,
    CertificationLevel.gueCave1 => l10n.enum_certificationLevel_gueCave1,
    CertificationLevel.gueCave2 => l10n.enum_certificationLevel_gueCave2,
    CertificationLevel.gueDpv => l10n.enum_certificationLevel_gueDpv,
    CertificationLevel.other => l10n.enum_certificationLevel_other,
  };
}
