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
    CertificationLevel.diveGuide,
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
    CertificationLevel.diveGuide,
    CertificationLevel.diveMaster,
    CertificationLevel.assistantInstructor,
    CertificationLevel.instructor,
  ];

  static const List<CertificationLevel> _nauiSdiLadder = [
    CertificationLevel.openWater,
    CertificationLevel.advancedOpenWater,
    CertificationLevel.rescue,
    CertificationLevel.masterDiver,
    CertificationLevel.diveGuide,
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
    CertificationLevel.diveGuide,
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

  /// FFESSM progression ladder (issue #690): the youth cursus, then the
  /// Niveaux, then the E1-E4 teaching track. The modular PE/PA aptitudes and
  /// the Tek / safety qualifications are NOT rungs — a diver validates them
  /// alongside a Niveau, not in place of one — so they live in
  /// [_ffessmSpecialties]. CMAS-affiliated but distinctly named, so it does
  /// not reuse [_cmasLadder].
  static const List<CertificationLevel> _ffessmLadder = [
    CertificationLevel.ffessmPlongeurBronze,
    CertificationLevel.ffessmPlongeurArgent,
    CertificationLevel.ffessmPlongeurOr,
    CertificationLevel.ffessmN1,
    CertificationLevel.ffessmN2,
    CertificationLevel.ffessmN3,
    CertificationLevel.ffessmN4,
    CertificationLevel.ffessmN5,
    CertificationLevel.ffessmInitiateur,
    CertificationLevel.ffessmE2,
    CertificationLevel.ffessmMf1,
    CertificationLevel.ffessmMf2,
  ];

  /// FFESSM's modular qualifications, offered instead of the shared
  /// [specialties] for this agency: the PE/PA aptitudes (validated on their
  /// own, e.g. N1 + PA-20 + PE-40), the Tek mixed-gas / rebreather brevets,
  /// the safety and the technical qualifications. FFESSM names its own, the
  /// same way the CMAS/BSAC/GUE ratings are their own values.
  static const List<CertificationLevel> _ffessmSpecialties = [
    CertificationLevel.ffessmPe12,
    CertificationLevel.ffessmPe40,
    CertificationLevel.ffessmPe60,
    CertificationLevel.ffessmPa12,
    CertificationLevel.ffessmPa20,
    CertificationLevel.ffessmPa40,
    CertificationLevel.ffessmNitrox,
    CertificationLevel.ffessmNitroxConfirme,
    CertificationLevel.ffessmMoniteurNitroxConfirme,
    CertificationLevel.ffessmTrimixElementaire,
    CertificationLevel.ffessmTrimix,
    CertificationLevel.ffessmMoniteurTrimix,
    CertificationLevel.ffessmRecycleurScr,
    CertificationLevel.ffessmRecycleurCcr,
    CertificationLevel.ffessmMoniteurRecycleurCcr,
    CertificationLevel.ffessmRifap,
    CertificationLevel.ffessmAnteor,
    CertificationLevel.ffessmVetementEtanche,
    CertificationLevel.ffessmSidemount,
    CertificationLevel.ffessmTiv,
    CertificationLevel.ffessmFormateurTiv,
    CertificationLevel.ffessmBio1,
    CertificationLevel.ffessmBio2,
    CertificationLevel.ffessmFormateurBio1,
    CertificationLevel.ffessmFormateurBio2,
    CertificationLevel.ffessmFormateurBio3,
    CertificationLevel.ffessmSouterrain1,
    CertificationLevel.ffessmSouterrain2,
    CertificationLevel.ffessmSouterrain3,
    CertificationLevel.ffessmPhoto1,
    CertificationLevel.ffessmPhoto2,
    CertificationLevel.ffessmPhoto3,
    CertificationLevel.ffessmVideo1,
    CertificationLevel.ffessmVideo2,
    CertificationLevel.ffessmVideo3,
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
        CertificationAgency.ffessm => _ffessmLadder,
        CertificationAgency.other || null => _genericLadder,
      };

  /// Specialties offered for [agency] that are not already on its ladder.
  /// Used to render the dropdown's "Specialties" group without repeating a
  /// level that the ladder already lists.
  static List<CertificationLevel> specialtiesFor(CertificationAgency? agency) {
    final ladder = ladderFor(agency);
    final pool = agency == CertificationAgency.ffessm
        ? _ffessmSpecialties
        : specialties;
    return pool.where((s) => !ladder.contains(s)).toList();
  }

  /// Full dropdown list for an agency: ladder, then specialties not already
  /// on the ladder, then [CertificationLevel.other] last. When [ensure] is
  /// provided and missing from the list (a stored value from another
  /// agency's catalog), it is inserted before `other` so existing data
  /// always renders.
  static List<CertificationLevel> levelsFor(
    CertificationAgency? agency, {
    CertificationLevel? ensure,
  }) {
    final result = [...ladderFor(agency), ...specialtiesFor(agency)];
    if (ensure != null &&
        ensure != CertificationLevel.other &&
        !result.contains(ensure)) {
      result.add(ensure);
    }
    result.add(CertificationLevel.other);
    return result;
  }
}
