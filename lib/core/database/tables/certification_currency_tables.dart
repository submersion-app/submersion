/// Certification currency: the rule catalog, per certification overrides
/// and the event ledger (issue #2267), with the built-in rule seed.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/buddy_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';

/// The certification currency rule catalog (issue #2267). Built-in rows are
/// reference data: seeded on every device, excluded from sync export, spared
/// by deleteAllRecords, and re-asserted on every open. They are never edited
/// in place, because an edit to a row the export omits would be device-local
/// and silent; the UI copies a built-in into a custom rule carrying
/// [supersedesRuleId] instead.
@DataClassName('CurrencyRuleRow')
class CertificationCurrencyRules extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();

  /// `date` counts from a date on the card; `activity` counts from the last
  /// qualifying dive. See CurrencyClockKind.
  TextColumn get clockKind => text()();

  /// JSON arrays of CertificationAgency and CertificationLevel names. '[]'
  /// means "any", the same convention as ServiceKinds.applicableTypes.
  TextColumn get applicableAgencies =>
      text().withDefault(const Constant('[]'))();
  TextColumn get applicableLevels => text().withDefault(const Constant('[]'))();

  IntColumn get lapseDays => integer()();
  IntColumn get leadDays => integer()();

  /// Activity clocks only: which dives count. '[]' means any dive.
  TextColumn get countedDiveTypeIds =>
      text().withDefault(const Constant('[]'))();
  TextColumn get countedDiveModes => text().withDefault(const Constant('[]'))();

  /// Built-ins name an l10n key resolved at render time, so a seeded row
  /// never stores a translated string. Custom rules carry the diver's own
  /// text, which is never translated.
  TextColumn get advisoryKey => text().nullable()();
  TextColumn get advisoryText => text().nullable()();

  /// Set on a custom rule that replaces a built-in one. The engine drops the
  /// built-in while a live custom rule supersedes it.
  TextColumn get supersedesRuleId => text().nullable()();

  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per (certification, rule) overrides. An absent row inherits everything,
/// which is what lets rules apply by default with nothing seeded per card.
@DataClassName('CurrencyPrefRow')
class CertificationCurrencyPrefs extends Table {
  TextColumn get id => text()();
  TextColumn get certificationId =>
      text().references(Certifications, #id, onDelete: KeyAction.cascade)();

  /// Plain text, no FK, so a pref survives deleting the custom rule it
  /// referenced, exactly as service_records.service_kind_id does.
  TextColumn get ruleId => text()();

  IntColumn get lapseDaysOverride => integer().nullable()();
  IntColumn get leadDaysOverride => integer().nullable()();

  /// NULL inherits the rule's mapping; '[]' is the diver saying "any dive
  /// counts". The two are different answers and must not be collapsed.
  TextColumn get countedDiveTypeIds => text().nullable()();
  TextColumn get countedDiveModes => text().nullable()();

  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// What the diver did to reset a clock: a refresher, a renewal, a
/// revalidation. The ledger twin of ServiceRecords.
@DataClassName('CurrencyEventRow')
class CertificationCurrencyEvents extends Table {
  TextColumn get id => text()();
  TextColumn get certificationId =>
      text().references(Certifications, #id, onDelete: KeyAction.cascade)();

  /// Nullable and FK-free: a refresher the diver logged without tying it to
  /// a rule still belongs in the history.
  TextColumn get ruleId => text().nullable()();

  TextColumn get eventType => text()();
  IntColumn get eventDate => integer()();
  TextColumn get provider => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The built-in currency rules (issue #2267). INSERT OR IGNORE, so running
/// this on every open re-seeds a stranded catalog without ever rewriting a
/// row the diver has tuned. A later release adds rules here; it never
/// UPDATEs an existing one, because a default correction is for fresh
/// databases only.
///
/// lead_days is the amber window before lapse_days, so "amber at 6 months,
/// red at 12" is lapse_days 365 with lead_days 185.
///
/// The four refresher rules cover every rung of their agencies' ladders in
/// CertificationLevelCatalog, professional rungs included, resolved to level
/// names here so a later change to the catalog never moves a diver's rules.
/// currency_seed_catalog_test pins the two together, and fails when a new
/// agency is covered by no refresher (ACUC joined with issue #690). DAN's
/// provider credentials renew with first aid, its instructors with
/// membership.
///
/// tdi_refresher's levels (issue #3072) also name 'cave', 'rebreather' and
/// 'instructor': the three old generic TDI ladder rungs the migration
/// deliberately leaves unrewritten, because they could mean one of several
/// new TDI courses. They moved here, not from a guess at which new course a
/// diver meant, but because generic_refresher dropped TDI (TDI has its own
/// rule now) and an untouched old value must keep the activity-based
/// refresher clock it already had, same as before this issue. 'techDiver'
/// and 'wreck' are not added here: neither was ever on the tech ladder
/// generic_refresher covered, so there is nothing to preserve for them.
const String kSeedBuiltInCurrencyRulesSql = '''
  INSERT OR IGNORE INTO certification_currency_rules
    (id, diver_id, name, clock_kind, applicable_agencies, applicable_levels,
     lapse_days, lead_days, counted_dive_type_ids, counted_dive_modes,
     advisory_key, advisory_text, supersedes_rule_id, is_built_in,
     created_at, updated_at)
  SELECT r.id, NULL, r.name, r.clock_kind, r.agencies, r.levels,
         r.lapse_days, r.lead_days, r.dive_types, r.dive_modes,
         r.advisory_key, NULL, NULL, 1, n.now_ms, n.now_ms
  FROM (
    SELECT 'padi_reactivate' AS id, 'PADI refresher (ReActivate)' AS name,
      'activity' AS clock_kind, '["padi"]' AS agencies,
      '["openWater","advancedOpenWater","rescue","masterDiver","diveGuide","diveMaster","assistantInstructor","instructor","masterInstructor","courseDirector"]'
        AS levels,
      365 AS lapse_days, 185 AS lead_days, '[]' AS dive_types,
      '[]' AS dive_modes,
      'currencyRule_padi_reactivate_advisory' AS advisory_key
    UNION ALL SELECT 'ssi_skills_update', 'SSI Scuba Skills Update',
      'activity', '["ssi"]',
      '["openWater","advancedOpenWater","rescue","masterDiver","diveGuide","diveMaster","assistantInstructor","instructor"]',
      365, 185, '[]', '[]', 'currencyRule_ssi_skills_update_advisory'
    UNION ALL SELECT 'generic_refresher', 'Refresher',
      'activity',
      '["naui","sdi","raid","bsac","cmas","iantd","psai","ffessm","acuc","other"]',
      '["openWater","advancedOpenWater","rescue","masterDiver","diveGuide","diveMaster","assistantInstructor","instructor","courseDirector","masterInstructor","nitrox","advancedNitrox","decompression","extendedRange","trimix","advancedTrimix","cavern","cave","rebreather","bsacOceanDiver","bsacSportsDiver","bsacDiveLeader","bsacAdvancedDiver","bsacFirstClassDiver","bsacOpenWaterInstructor","bsacAdvancedInstructor","bsacNationalInstructor","cmas1StarDiver","cmas2StarDiver","cmas3StarDiver","cmas4StarDiver","cmas3StarDiverAssistantInstructor","cmas4StarDiverAssistantInstructor","cmas1StarInstructor","cmas2StarInstructor","cmas3StarInstructor","ffessmPlongeurBronze","ffessmPlongeurArgent","ffessmPlongeurOr","ffessmN1","ffessmN2","ffessmN3","ffessmN4","ffessmN5","ffessmInitiateur","ffessmE2","ffessmMf1","ffessmMf2","acucScubaDiver","acucAdvancedDiver","acucRescueLeader","acucUnderwaterGuide","acucTeachingAssistant","acucOpenWaterInstructor","acucAdvancedInstructor","acucInstructorTrainer","acucInstructorTrainerEvaluator"]',
      365, 185, '[]', '[]', 'currencyRule_generic_refresher_advisory'
    UNION ALL SELECT 'tdi_refresher', 'TDI refresher',
      'activity', '["tdi"]',
      '["tdiNitroxDiver","tdiAdvancedNitroxDiver","tdiDecompressionProceduresDiver","tdiHelitroxDiver","tdiExtendedRangeDiver","tdiTrimixDiver","tdiAdvancedTrimixDiver","tdiTechnicalDivemaster","tdiInstructor","tdiInstructorTrainer","cave","rebreather","instructor"]',
      365, 185, '[]', '[]', 'currencyRule_tdi_refresher_advisory'
    UNION ALL SELECT 'first_aid_24mo', 'First aid and CPR renewal',
      'date', '[]',
      '["firstAid","oxygenProvider","danBls","danEmergencyOxygen","danDfaPro","danDemp","danAdvancedOxygen","danNeurologicalAssessment","danMarineLifeInjuries"]',
      730, 60, '[]', '[]', 'currencyRule_first_aid_advisory'
    UNION ALL SELECT 'pro_membership_annual',
      'Professional membership renewal', 'date',
      '["padi","ssi","naui","sdi","tdi","raid","bsac","cmas","iantd","psai","acuc","dan","other"]',
      '["diveGuide","diveMaster","assistantInstructor","instructor","masterInstructor","courseDirector","tdiTechnicalDivemaster","tdiInstructor","tdiInstructorTrainer","tdiNonDivingSpecialtyInstructor","cmas1StarInstructor","cmas2StarInstructor","cmas3StarInstructor","bsacOpenWaterInstructor","bsacAdvancedInstructor","bsacNationalInstructor","acucUnderwaterGuide","acucTeachingAssistant","acucOpenWaterInstructor","acucAdvancedInstructor","acucInstructorTrainer","acucInstructorTrainerEvaluator","danInstructor","danInstructorTrainer"]',
      365, 45, '[]', '[]', 'currencyRule_pro_membership_advisory'
    UNION ALL SELECT 'gue_revalidation', 'GUE revalidation',
      'date', '["gue"]', '[]',
      1095, 90, '[]', '[]', 'currencyRule_gue_revalidation_advisory'
    UNION ALL SELECT 'ffessm_licence_annual',
      'FFESSM licence and medical certificate', 'date', '["ffessm"]', '[]',
      365, 45, '[]', '[]', 'currencyRule_ffessm_licence_advisory'
    UNION ALL SELECT 'cave_currency', 'Cave currency',
      'activity', '[]',
      '["cave","cavern","gueCave1","gueCave2","tdiCavernDiver","tdiIntroToCaveDiver","tdiFullCaveDiver","tdiRebreatherCavernDiver","tdiRebreatherIntroCaveDiver","tdiRebreatherFullCaveDiver","tdiCaveSurveyingDiver","tdiStageCaveDiver","tdiDpvCaveDiver"]',
      365, 90, '["cave","cavern"]', '[]',
      'currencyRule_cave_currency_advisory'
    UNION ALL SELECT 'rebreather_currency', 'Rebreather currency',
      'activity', '[]',
      '["rebreather","tdiAirDiluentCcrDiver","tdiSemiClosedRebreatherDiver","tdiAirDiluentDecoCcrDiver","tdiHelitroxCcrDiver","tdiMixedGasCcrDiver","tdiAdvancedMixedGasCcrDiver","tdiRebreatherCavernDiver","tdiRebreatherIntroCaveDiver","tdiRebreatherFullCaveDiver"]',
      180, 90, '[]', '["ccr","scr"]',
      'currencyRule_rebreather_currency_advisory'
    UNION ALL SELECT 'deco_currency', 'Decompression currency',
      'activity', '[]',
      '["decompression","trimix","advancedTrimix","advancedNitrox","techDiver","extendedRange","gueTech1","gueTech2","tdiDecompressionProceduresDiver","tdiTrimixDiver","tdiAdvancedTrimixDiver","tdiAdvancedNitroxDiver","tdiExtendedRangeDiver","tdiHelitroxDiver"]',
      365, 90, '["technical"]', '[]',
      'currencyRule_deco_currency_advisory'
  ) r
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';
