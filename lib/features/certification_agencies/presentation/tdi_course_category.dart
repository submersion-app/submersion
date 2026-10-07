import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The five categories TDI's own course catalog groups itself into
/// (tdisdi.com/tdi/get-certified, issue #3072). Display-only: it decides
/// which header a TDI-specific [CertificationLevel] renders under in the
/// certification dropdown, and has no bearing on what is stored or on
/// [CertificationLevelCatalog]'s ladder/specialty split. A level not in
/// [_categories] -- a legacy generic value, a custom level, or `other` --
/// has no category and renders without this grouping.
enum TdiCourseCategory {
  openCircuit,
  rebreather,
  service,
  overhead,
  professional;

  String label(AppLocalizations l10n) => switch (this) {
    TdiCourseCategory.openCircuit =>
      l10n.certifications_edit_group_tdiOpenCircuit,
    TdiCourseCategory.rebreather =>
      l10n.certifications_edit_group_tdiRebreather,
    TdiCourseCategory.service => l10n.certifications_edit_group_tdiService,
    TdiCourseCategory.overhead => l10n.certifications_edit_group_tdiOverhead,
    TdiCourseCategory.professional =>
      l10n.certifications_edit_group_tdiProfessional,
  };
}

const Map<CertificationLevel, TdiCourseCategory> _categories = {
  CertificationLevel.tdiNitroxDiver: TdiCourseCategory.openCircuit,
  CertificationLevel.tdiSidemountDiver: TdiCourseCategory.openCircuit,
  CertificationLevel.tdiIntroToTechDiving: TdiCourseCategory.openCircuit,
  CertificationLevel.tdiAdvancedNitroxDiver: TdiCourseCategory.openCircuit,
  CertificationLevel.tdiDecompressionProceduresDiver:
      TdiCourseCategory.openCircuit,
  CertificationLevel.tdiHelitroxDiver: TdiCourseCategory.openCircuit,
  CertificationLevel.tdiExtendedRangeDiver: TdiCourseCategory.openCircuit,
  CertificationLevel.tdiTrimixDiver: TdiCourseCategory.openCircuit,
  CertificationLevel.tdiAdvancedTrimixDiver: TdiCourseCategory.openCircuit,
  CertificationLevel.tdiAirDiluentCcrDiver: TdiCourseCategory.rebreather,
  CertificationLevel.tdiSemiClosedRebreatherDiver: TdiCourseCategory.rebreather,
  CertificationLevel.tdiAirDiluentDecoCcrDiver: TdiCourseCategory.rebreather,
  CertificationLevel.tdiHelitroxCcrDiver: TdiCourseCategory.rebreather,
  CertificationLevel.tdiMixedGasCcrDiver: TdiCourseCategory.rebreather,
  CertificationLevel.tdiAdvancedMixedGasCcrDiver: TdiCourseCategory.rebreather,
  CertificationLevel.tdiNitroxGasBlender: TdiCourseCategory.service,
  CertificationLevel.tdiAdvancedGasBlender: TdiCourseCategory.service,
  CertificationLevel.tdiO2ServiceTechnician: TdiCourseCategory.service,
  CertificationLevel.tdiCavernDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiIntroToCaveDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiAdvancedWreckDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiFullCaveDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiRebreatherCavernDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiRebreatherIntroCaveDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiRebreatherFullCaveDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiDpvDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiMineDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiCaveSurveyingDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiStageCaveDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiDpvCaveDiver: TdiCourseCategory.overhead,
  CertificationLevel.tdiTechnicalDivemaster: TdiCourseCategory.professional,
  CertificationLevel.tdiNonDivingSpecialtyInstructor:
      TdiCourseCategory.professional,
  CertificationLevel.tdiInstructor: TdiCourseCategory.professional,
  CertificationLevel.tdiInstructorTrainer: TdiCourseCategory.professional,
};

/// The TDI course category [level] belongs to, or null for anything else
/// (a legacy generic value, a custom level, or `other`).
TdiCourseCategory? tdiCourseCategoryOf(CertificationLevel level) =>
    _categories[level];

/// Groups [entries] by TDI course category (issue #3072), for any screen
/// that lists an agency's ladder and/or specialties and wants to show TDI's
/// own five-category structure instead of the generic progression/
/// specialties split. [uncategorized] holds everything that cannot be
/// categorized this way: a diver's own custom level under the TDI agency
/// (any agency, built-in or not, can have one) has no TDI category, and
/// neither does a legacy value this build does not map.
({
  Map<TdiCourseCategory, List<LevelEntry>> byCategory,
  List<LevelEntry> uncategorized,
})
groupLevelEntriesByTdiCategory(List<LevelEntry> entries) {
  final byCategory = <TdiCourseCategory, List<LevelEntry>>{};
  final uncategorized = <LevelEntry>[];
  for (final entry in entries) {
    final builtIn = entry.builtIn;
    final category = builtIn == null ? null : tdiCourseCategoryOf(builtIn);
    if (category == null) {
      uncategorized.add(entry);
    } else {
      (byCategory[category] ??= []).add(entry);
    }
  }
  return (byCategory: byCategory, uncategorized: uncategorized);
}

/// [groupLevelEntriesByTdiCategory] over the TDI agency's full catalog
/// (ladder and specialties combined), for a screen that just wants "TDI's
/// levels, grouped" without composing the catalog lookups itself.
({
  Map<TdiCourseCategory, List<LevelEntry>> byCategory,
  List<LevelEntry> uncategorized,
})
groupTdiCatalog(CertificationCatalog catalog) {
  final agencyId = CertificationAgency.tdi.name;
  return groupLevelEntriesByTdiCategory([
    ...catalog.ladderFor(agencyId),
    ...catalog.specialtiesFor(agencyId),
  ]);
}
