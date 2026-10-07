import 'dart:ui' show Color;

// The certification enums, split out of enums.dart (which re-exports them)
// to keep that file under the 800-line limit (issue #690).

/// Certification agencies
enum CertificationAgency {
  padi('PADI'),
  ssi('SSI'),
  naui('NAUI'),
  sdi('SDI'),
  tdi('TDI'),
  gue('GUE'),
  raid('RAID'),
  bsac('BSAC'),
  cmas('CMAS'),
  iantd('IANTD'),
  psai('PSAI'),
  ffessm('FFESSM'),
  // American Canadian Underwater Certifications and Divers Alert Network
  // (issue #690). Brand names, never translated.
  acuc('ACUC'),
  dan('DAN'),
  other('Other');

  final String displayName;
  const CertificationAgency(this.displayName);

  /// The built-in whose enum name is [id], or null for a custom agency id,
  /// an unknown slug or null. Stored ids are enum names (issue #690).
  static CertificationAgency? fromId(String? id) {
    if (id == null) return null;
    for (final a in values) {
      if (a.name == id) return a;
    }
    return null;
  }

  /// Primary brand color for this agency
  Color get primaryColor => switch (this) {
    CertificationAgency.padi => const Color(0xFF004990),
    CertificationAgency.ssi => const Color(0xFF1a237e),
    CertificationAgency.naui => const Color(0xFF1b5e20),
    CertificationAgency.sdi => const Color(0xFF0d47a1),
    CertificationAgency.tdi => const Color(0xFF4a148c),
    CertificationAgency.gue => const Color(0xFF424242),
    CertificationAgency.raid => const Color(0xFFb71c1c),
    CertificationAgency.bsac => const Color(0xFF1565c0),
    CertificationAgency.cmas => const Color(0xFF00695c),
    CertificationAgency.iantd => const Color(0xFF283593),
    CertificationAgency.psai => const Color(0xFF2e7d32),
    CertificationAgency.ffessm => const Color(0xFF00529b),
    CertificationAgency.acuc => const Color(0xFF0D3B7A),
    CertificationAgency.dan => const Color(0xFF9E1B32),
    CertificationAgency.other => const Color(0xFF00838f),
  };

  /// Secondary brand color for gradient effects
  Color get secondaryColor => switch (this) {
    CertificationAgency.padi => const Color(0xFF0066CC),
    CertificationAgency.ssi => const Color(0xFF42a5f5),
    CertificationAgency.naui => const Color(0xFF43a047),
    CertificationAgency.sdi => const Color(0xFF1976d2),
    CertificationAgency.tdi => const Color(0xFF7b1fa2),
    CertificationAgency.gue => const Color(0xFF757575),
    CertificationAgency.raid => const Color(0xFFe53935),
    CertificationAgency.bsac => const Color(0xFF42a5f5),
    CertificationAgency.cmas => const Color(0xFF26a69a),
    CertificationAgency.iantd => const Color(0xFF5c6bc0),
    CertificationAgency.psai => const Color(0xFF66bb6a),
    CertificationAgency.ffessm => const Color(0xFF1e88e5),
    CertificationAgency.acuc => const Color(0xFF2E6BC4),
    CertificationAgency.dan => const Color(0xFFD23C52),
    CertificationAgency.other => const Color(0xFF26c6da),
  };
}

/// Common certification levels
/// A certification a diver holds. Presented in the UI as "Certification" --
/// the values are course and rating names (Open Water, Nitrox, Tech 1), not
/// a level scale, and the UI groups them into progression vs specialties via
/// CertificationLevelCatalog.
///
/// The type keeps the historical `Level` name deliberately: values are
/// persisted as enum-name text and round-trip through UDDF import/export and
/// the sync field maps, so renaming buys nothing a user can see.
enum CertificationLevel {
  openWater('Open Water'),
  advancedOpenWater('Advanced Open Water'),
  rescue('Rescue Diver'),
  diveGuide('Dive Guide'),
  diveMaster('Divemaster'),
  instructor('Instructor'),
  masterInstructor('Master Instructor'),
  courseDirector('Course Director'),
  nitrox('Nitrox'),
  advancedNitrox('Advanced Nitrox'),
  decompression('Decompression'),
  trimix('Trimix'),
  cavern('Cavern'),
  cave('Cave'),
  wreck('Wreck'),
  sidemount('Sidemount'),
  rebreather('Rebreather'),
  techDiver('Tech Diver'),
  // Agency-agnostic safety credentials. These genuinely expire on a date
  // (typically 24 months) and are the prerequisite that lapses first for
  // rescue and professional ratings, so certification currency needs them
  // as first-class values rather than folding them into `other`.
  firstAid('First Aid / CPR'),
  oxygenProvider('Emergency Oxygen Provider'),
  // Generic ladder additions (issue #546)
  masterDiver('Master Diver'),
  assistantInstructor('Assistant Instructor'),
  // Technical ladder additions
  extendedRange('Extended Range'),
  advancedTrimix('Advanced Trimix'),
  // CMAS star grades
  cmas1StarDiver('1★ Diver'),
  cmas2StarDiver('2★ Diver'),
  cmas3StarDiver('3★ Diver'),
  cmas4StarDiver('4★ Diver'),
  cmas3StarDiverAssistantInstructor('3★ Diver - Assistant Instructor'),
  cmas4StarDiverAssistantInstructor('4★ Diver - Assistant Instructor'),
  cmas1StarInstructor('1★ Instructor'),
  cmas2StarInstructor('2★ Instructor'),
  cmas3StarInstructor('3★ Instructor'),
  // BSAC grades
  bsacOceanDiver('Ocean Diver'),
  bsacSportsDiver('Sports Diver'),
  bsacDiveLeader('Dive Leader'),
  bsacAdvancedDiver('Advanced Diver'),
  bsacFirstClassDiver('First Class Diver'),
  bsacOpenWaterInstructor('Open Water Instructor'),
  bsacAdvancedInstructor('Advanced Instructor'),
  bsacNationalInstructor('National Instructor'),
  // GUE ratings
  gueFundamentals('Fundamentals'),
  gueRec1('Rec 1'),
  gueRec2('Rec 2'),
  gueRec3('Rec 3'),
  gueTech1('Tech 1'),
  gueTech2('Tech 2'),
  gueCave1('Cave 1'),
  gueCave2('Cave 2'),
  gueDpv('DPV'),
  // FFESSM — Fédération française d'études et de sports sous-marins (issue #690).
  // French brevets are proper nouns, kept untranslated like the CMAS/BSAC/GUE
  // ratings above. This is the scuba cursus of the FFESSM Manuel de Formation
  // Technique (août 2023): youth track, modular PE/PA aptitudes, Niveaux,
  // E-grade teaching ladder, Tek (mixed gas / rebreather), safety and a few
  // technical qualifications. A diver routinely holds an aptitude or a Tek
  // brevet without the "matching" Niveau (e.g. N1 + PA-20 + PE-40), so those
  // are first-class values in the specialties group, not ladder rungs.
  // Youth cursus (Plongée Jeunes)
  ffessmPlongeurBronze('Plongeur de Bronze'),
  ffessmPlongeurArgent('Plongeur d\'Argent'),
  ffessmPlongeurOr('Plongeur d\'Or'),
  // Niveaux (N4 and N5 also belong to the cadre cursus)
  ffessmN1('N1 - Plongeur Niveau 1 (PE20)'),
  ffessmN2('N2 - Plongeur Niveau 2 (PA20, PE40)'),
  ffessmN3('N3 - Plongeur Niveau 3 (PA60)'),
  ffessmN4('N4 - Guide de Palanquée'),
  ffessmN5('N5 - Directeur de Plongée'),
  // Teaching ladder
  ffessmInitiateur('E1 - Initiateur'),
  ffessmE2('E2 - Encadrant'),
  ffessmMf1('MF1 - Moniteur Fédéral 1er degré (E3)'),
  ffessmMf2('MF2 - Moniteur Fédéral 2e degré (E4)'),
  // Modular aptitudes — PE = Plongeur Encadré (supervised), PA = Plongeur
  // Autonome (autonomous). PE-20 is N1 and PA-60 is N3, so those two are not
  // separately issued. The six below are (MFT Généralités p.3).
  ffessmPe12('PE12 - Plongeur encadré 12 m'),
  ffessmPe40('PE40 - Plongeur encadré 40 m'),
  ffessmPe60('PE60 - Plongeur encadré 60 m'),
  ffessmPa12('PA12 - Plongeur autonome 12 m'),
  ffessmPa20('PA20 - Plongeur autonome 20 m'),
  ffessmPa40('PA40 - Plongeur autonome 40 m'),
  // Tek — nitrox, trimix, rebreather. FFESSM names its own.
  ffessmNitrox('Plongeur Nitrox'),
  ffessmNitroxConfirme('Plongeur Nitrox confirmé'),
  ffessmMoniteurNitroxConfirme('Moniteur Nitrox confirmé'),
  ffessmTrimixElementaire('Plongeur Trimix élémentaire'),
  ffessmTrimix('Plongeur Trimix'),
  ffessmMoniteurTrimix('Moniteur Trimix'),
  ffessmRecycleurScr('SCR - Plongeur recycleur circuit semi-fermé'),
  ffessmRecycleurCcr('CCR - Plongeur recycleur circuit fermé'),
  ffessmMoniteurRecycleurCcr('CCR - Moniteur recycleur circuit fermé'),
  // Safety
  ffessmRifap('RIFAP - RIFA Plongée'),
  ffessmAnteor('ANTEOR'),
  // Technical qualifications
  ffessmVetementEtanche('Qualification Vêtement étanche'),
  ffessmSidemount('Sidemount de loisir'),
  ffessmTiv('TIV - Technicien d\'Inspection Visuelle'),
  ffessmFormateurTiv('Formateur de TIV'),
  // Scuba-diving activity commissions (biology, cave, underwater imaging).
  // Non-scuba disciplines (apnea, finswimming, hockey, spearfishing...) stay
  // out — see #690.
  ffessmBio1('PB1 - Plongeur Bio Niveau 1'),
  ffessmBio2('PB2 - Plongeur Bio Niveau 2'),
  ffessmFormateurBio1('FB1 - Formateur Bio Niveau 1'),
  ffessmFormateurBio2('FB2 - Formateur Bio Niveau 2'),
  ffessmFormateurBio3('FB3 - Formateur Bio Niveau 3'),
  ffessmSouterrain1('PS1 - Plongeur Souterrain Niveau 1'),
  ffessmSouterrain2('PS2 - Plongeur Souterrain Niveau 2'),
  ffessmSouterrain3('PS3 - Plongeur Souterrain Niveau 3'),
  ffessmPhoto1('Photographe sous-marin Niveau 1'),
  ffessmPhoto2('Photographe sous-marin Niveau 2'),
  ffessmPhoto3('Photographe sous-marin Niveau 3'),
  ffessmVideo1('Vidéaste sous-marin Niveau 1'),
  ffessmVideo2('Vidéaste sous-marin Niveau 2'),
  ffessmVideo3('Vidéaste sous-marin Niveau 3'),
  // ACUC, American Canadian Underwater Certifications (issue #690). Proper
  // names, kept untranslated like the BSAC, GUE and FFESSM ratings.
  acucScubaDiver('Scuba Diver'),
  acucAdvancedDiver('Advanced Diver'),
  acucRescueLeader('Rescue Leader'),
  acucUnderwaterGuide('Underwater Guide'),
  acucTeachingAssistant('Teaching Assistant'),
  acucOpenWaterInstructor('Open Water Instructor'),
  acucAdvancedInstructor('Advanced Instructor'),
  acucInstructorTrainer('Instructor Trainer'),
  acucInstructorTrainerEvaluator('Instructor Trainer Evaluator'),
  // DAN, Divers Alert Network (issue #690). First-aid and emergency
  // credentials, not diver grades.
  danBls('Basic Life Support: CPR and First Aid'),
  danEmergencyOxygen('Emergency Oxygen for Scuba Diving Injuries'),
  danDfaPro('Diving First Aid for Professional Divers'),
  danDemp('Diving Emergency Management Provider'),
  danInstructor('DAN Instructor'),
  danInstructorTrainer('DAN Instructor Trainer'),
  danAdvancedOxygen('Advanced Oxygen Provider'),
  danNeurologicalAssessment('On-Site Neurological Assessment'),
  danMarineLifeInjuries('First Aid for Hazardous Marine Life Injuries'),
  // TDI, Technical Diving International (issue #3072). Proper course names
  // from tdisdi.com/tdi/get-certified, kept untranslated like the other
  // agencies' own grade names. IANTD and PSAI stay on the shared generic
  // tech ladder; this is TDI's own structure only.
  // Open Circuit
  tdiNitroxDiver('Nitrox Diver'),
  tdiSidemountDiver('Sidemount Diver'),
  tdiIntroToTechDiving('Intro to Tech Diving'),
  tdiAdvancedNitroxDiver('Advanced Nitrox Diver'),
  tdiDecompressionProceduresDiver('Decompression Procedures Diver'),
  tdiHelitroxDiver('Helitrox Diver'),
  tdiExtendedRangeDiver('Extended Range Diver'),
  tdiTrimixDiver('Trimix Diver'),
  tdiAdvancedTrimixDiver('Advanced Trimix Diver'),
  // Rebreather
  tdiAirDiluentCcrDiver('Air Diluent CCR Diver'),
  tdiSemiClosedRebreatherDiver('Semi Closed Rebreather Diver'),
  tdiAirDiluentDecoCcrDiver('Air Diluent Deco CCR Diver'),
  tdiHelitroxCcrDiver('Helitrox CCR Diver'),
  tdiMixedGasCcrDiver('Mixed Gas CCR Diver'),
  tdiAdvancedMixedGasCcrDiver('Advanced Mixed Gas CCR Diver'),
  // Service
  tdiNitroxGasBlender('Nitrox Gas Blender'),
  tdiAdvancedGasBlender('Advanced Gas Blender'),
  tdiO2ServiceTechnician('O2 Service Technician'),
  // Overhead
  tdiCavernDiver('Cavern Diver'),
  tdiIntroToCaveDiver('Intro to Cave Diver'),
  tdiAdvancedWreckDiver('Advanced Wreck Diver'),
  tdiFullCaveDiver('Full Cave Diver'),
  tdiRebreatherCavernDiver('Rebreather Cavern Diver'),
  tdiRebreatherIntroCaveDiver('Rebreather Intro Cave Diver'),
  tdiRebreatherFullCaveDiver('Rebreather Full Cave Diver'),
  tdiDpvDiver('DPV Diver'),
  tdiMineDiver('Mine Diver'),
  tdiCaveSurveyingDiver('Cave Surveying Diver'),
  tdiStageCaveDiver('Stage Cave Diver'),
  tdiDpvCaveDiver('DPV Cave Diver'),
  // Professional
  tdiTechnicalDivemaster('Technical Divemaster'),
  tdiNonDivingSpecialtyInstructor('Non-Diving Specialty Instructor'),
  tdiInstructor('TDI Instructor'),
  tdiInstructorTrainer('TDI Instructor Trainer'),
  other('Other');

  final String displayName;
  const CertificationLevel(this.displayName);

  /// The built-in whose enum name is [id], or null (issue #690).
  static CertificationLevel? fromId(String? id) {
    if (id == null) return null;
    for (final l in values) {
      if (l.name == id) return l;
    }
    return null;
  }

  /// Grades that can independently certify students — drives the
  /// instructor picker (spec 2026-08-08 buddy-professional-roles-fold).
  /// Assistant-instructor grades are deliberately excluded.
  bool get isInstructorLevel => switch (this) {
    CertificationLevel.instructor ||
    CertificationLevel.masterInstructor ||
    CertificationLevel.courseDirector ||
    CertificationLevel.cmas1StarInstructor ||
    CertificationLevel.cmas2StarInstructor ||
    CertificationLevel.cmas3StarInstructor ||
    CertificationLevel.bsacOpenWaterInstructor ||
    CertificationLevel.bsacAdvancedInstructor ||
    CertificationLevel.bsacNationalInstructor ||
    CertificationLevel.acucOpenWaterInstructor ||
    CertificationLevel.acucAdvancedInstructor ||
    CertificationLevel.acucInstructorTrainer ||
    CertificationLevel.acucInstructorTrainerEvaluator ||
    CertificationLevel.danInstructor ||
    CertificationLevel.danInstructorTrainer ||
    CertificationLevel.ffessmMf1 ||
    CertificationLevel.ffessmMf2 ||
    CertificationLevel.tdiInstructor ||
    CertificationLevel.tdiInstructorTrainer => true,
    _ => false,
  };
}
