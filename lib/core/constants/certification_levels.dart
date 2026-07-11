import 'package:submersion/core/constants/enums.dart';

/// Agency-specific certification level catalogs (issue #546).
///
/// Each agency exposes its core progression ladder plus the cross-agency
/// [specialties] set. Levels are still persisted as enum-name text, so this
/// catalog only shapes what the dropdowns offer - it never restricts what
/// can be stored or parsed.
abstract final class CertificationLevelCatalog {
  /// Specialty levels offered by essentially every agency.
  static const List<CertificationLevel> specialties = [
    CertificationLevel.nitrox,
    CertificationLevel.advancedNitrox,
    CertificationLevel.decompression,
    CertificationLevel.trimix,
    CertificationLevel.cavern,
    CertificationLevel.cave,
    CertificationLevel.wreck,
    CertificationLevel.sidemount,
    CertificationLevel.rebreather,
    CertificationLevel.techDiver,
  ];

  static const List<CertificationLevel> _genericLadder = [
    CertificationLevel.openWater,
    CertificationLevel.advancedOpenWater,
    CertificationLevel.rescue,
    CertificationLevel.masterDiver,
    CertificationLevel.diveMaster,
    CertificationLevel.assistantInstructor,
    CertificationLevel.instructor,
    CertificationLevel.masterInstructor,
    CertificationLevel.courseDirector,
  ];

  static const List<CertificationLevel> _ssiLadder = [
    CertificationLevel.openWater,
    CertificationLevel.advancedOpenWater,
    CertificationLevel.rescue,
    CertificationLevel.masterDiver,
    CertificationLevel.diveMaster,
    CertificationLevel.assistantInstructor,
    CertificationLevel.instructor,
  ];

  static const List<CertificationLevel> _nauiSdiLadder = [
    CertificationLevel.openWater,
    CertificationLevel.advancedOpenWater,
    CertificationLevel.rescue,
    CertificationLevel.masterDiver,
    CertificationLevel.diveMaster,
    CertificationLevel.assistantInstructor,
    CertificationLevel.instructor,
    CertificationLevel.courseDirector,
  ];

  static const List<CertificationLevel> _raidLadder = [
    CertificationLevel.openWater,
    CertificationLevel.advancedOpenWater,
    CertificationLevel.rescue,
    CertificationLevel.masterDiver,
    CertificationLevel.diveMaster,
    CertificationLevel.instructor,
  ];

  static const List<CertificationLevel> _techLadder = [
    CertificationLevel.nitrox,
    CertificationLevel.advancedNitrox,
    CertificationLevel.decompression,
    CertificationLevel.extendedRange,
    CertificationLevel.trimix,
    CertificationLevel.advancedTrimix,
    CertificationLevel.cavern,
    CertificationLevel.cave,
    CertificationLevel.rebreather,
    CertificationLevel.instructor,
  ];

  static const List<CertificationLevel> _gueLadder = [
    CertificationLevel.gueFundamentals,
    CertificationLevel.gueRec1,
    CertificationLevel.gueRec2,
    CertificationLevel.gueRec3,
    CertificationLevel.gueTech1,
    CertificationLevel.gueTech2,
    CertificationLevel.gueCave1,
    CertificationLevel.gueCave2,
    CertificationLevel.gueDpv,
    CertificationLevel.instructor,
  ];

  static const List<CertificationLevel> _bsacLadder = [
    CertificationLevel.bsacOceanDiver,
    CertificationLevel.bsacSportsDiver,
    CertificationLevel.bsacDiveLeader,
    CertificationLevel.bsacAdvancedDiver,
    CertificationLevel.bsacFirstClassDiver,
    CertificationLevel.bsacOpenWaterInstructor,
    CertificationLevel.bsacAdvancedInstructor,
    CertificationLevel.bsacNationalInstructor,
  ];

  static const List<CertificationLevel> _cmasLadder = [
    CertificationLevel.cmas1StarDiver,
    CertificationLevel.cmas2StarDiver,
    CertificationLevel.cmas3StarDiver,
    CertificationLevel.cmas4StarDiver,
    CertificationLevel.cmas3StarDiverAssistantInstructor,
    CertificationLevel.cmas4StarDiverAssistantInstructor,
    CertificationLevel.cmas1StarInstructor,
    CertificationLevel.cmas2StarInstructor,
    CertificationLevel.cmas3StarInstructor,
  ];

  /// Core progression ladder for an agency, in rank order. A null agency
  /// (possible on buddies) behaves like [CertificationAgency.other].
  static List<CertificationLevel> ladderFor(CertificationAgency? agency) =>
      switch (agency) {
        CertificationAgency.padi => _genericLadder,
        CertificationAgency.ssi => _ssiLadder,
        CertificationAgency.naui || CertificationAgency.sdi => _nauiSdiLadder,
        CertificationAgency.raid => _raidLadder,
        CertificationAgency.tdi ||
        CertificationAgency.iantd ||
        CertificationAgency.psai => _techLadder,
        CertificationAgency.gue => _gueLadder,
        CertificationAgency.bsac => _bsacLadder,
        CertificationAgency.cmas => _cmasLadder,
        CertificationAgency.other || null => _genericLadder,
      };

  /// Full dropdown list for an agency: ladder, then specialties not already
  /// on the ladder, then [CertificationLevel.other] last. When [ensure] is
  /// provided and missing from the list (a stored value from another
  /// agency's catalog), it is inserted before `other` so existing data
  /// always renders.
  static List<CertificationLevel> levelsFor(
    CertificationAgency? agency, {
    CertificationLevel? ensure,
  }) {
    final ladder = ladderFor(agency);
    final result = [
      ...ladder,
      ...specialties.where((s) => !ladder.contains(s)),
    ];
    if (ensure != null &&
        ensure != CertificationLevel.other &&
        !result.contains(ensure)) {
      result.add(ensure);
    }
    result.add(CertificationLevel.other);
    return result;
  }
}
