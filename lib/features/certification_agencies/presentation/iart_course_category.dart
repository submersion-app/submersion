import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The five categories IART's own course catalog groups itself into
/// (iart.de/kursfinder, issue #3357). Display-only: it decides which header
/// an IART-specific [CertificationLevel] renders under in the certification
/// dropdown, and has no bearing on what is stored or on
/// [CertificationLevelCatalog]'s ladder/specialty split. A level not in
/// [_categories] -- a custom level, or `other` -- has no category and
/// renders without this grouping.
enum IartCourseCategory {
  openCircuit,
  rebreather,
  overhead,
  service,
  professional;

  String label(AppLocalizations l10n) => switch (this) {
    IartCourseCategory.openCircuit =>
      l10n.certifications_edit_group_iartOpenCircuit,
    IartCourseCategory.rebreather =>
      l10n.certifications_edit_group_iartRebreather,
    IartCourseCategory.overhead => l10n.certifications_edit_group_iartOverhead,
    IartCourseCategory.service => l10n.certifications_edit_group_iartService,
    IartCourseCategory.professional =>
      l10n.certifications_edit_group_iartProfessional,
  };
}

const Map<CertificationLevel, IartCourseCategory> _categories = {
  CertificationLevel.iartOpenWaterNitroxDiver: IartCourseCategory.openCircuit,
  CertificationLevel.iartAdvancedNitroxDiver: IartCourseCategory.openCircuit,
  CertificationLevel.iartRecreationalTrimix: IartCourseCategory.openCircuit,
  CertificationLevel.iartExtendedRangeNormoxicTrimix:
      IartCourseCategory.openCircuit,
  CertificationLevel.iartSidemount: IartCourseCategory.openCircuit,
  CertificationLevel.iartDecompression: IartCourseCategory.openCircuit,
  CertificationLevel.iartDriftDiving: IartCourseCategory.openCircuit,
  CertificationLevel.iartNightDiving: IartCourseCategory.openCircuit,
  CertificationLevel.iartDrysuitDiving: IartCourseCategory.openCircuit,
  CertificationLevel.iartRebreatherLevel1: IartCourseCategory.rebreather,
  CertificationLevel.iartRebreatherLevel2: IartCourseCategory.rebreather,
  CertificationLevel.iartRebreatherLevel3: IartCourseCategory.rebreather,
  CertificationLevel.iartRebreatherRescue: IartCourseCategory.rebreather,
  CertificationLevel.iartCavern: IartCourseCategory.overhead,
  CertificationLevel.iartCaveIntroduce: IartCourseCategory.overhead,
  CertificationLevel.iartFullCave: IartCourseCategory.overhead,
  CertificationLevel.iartTechCave: IartCourseCategory.overhead,
  CertificationLevel.iartCaveDpv: IartCourseCategory.overhead,
  CertificationLevel.iartWreck: IartCourseCategory.overhead,
  CertificationLevel.iartDpvScooter: IartCourseCategory.overhead,
  CertificationLevel.iartGasBlender: IartCourseCategory.service,
  CertificationLevel.iartIoc: IartCourseCategory.professional,
  CertificationLevel.iartItp: IartCourseCategory.professional,
  CertificationLevel.iartIe: IartCourseCategory.professional,
  CertificationLevel.iartIdc: IartCourseCategory.professional,
  CertificationLevel.iartDiveGuide: IartCourseCategory.professional,
};

/// The IART course category [level] belongs to, or null for anything else
/// (a custom level, or `other`).
IartCourseCategory? iartCourseCategoryOf(CertificationLevel level) =>
    _categories[level];

/// Groups [entries] by IART course category (issue #3357), for any screen
/// that lists an agency's ladder and/or specialties and wants to show
/// IART's own five-category structure instead of the generic progression/
/// specialties split. [uncategorized] holds everything that cannot be
/// categorized this way: a diver's own custom level under the IART agency
/// has no IART category.
({
  Map<IartCourseCategory, List<LevelEntry>> byCategory,
  List<LevelEntry> uncategorized,
})
groupLevelEntriesByIartCategory(List<LevelEntry> entries) {
  final byCategory = <IartCourseCategory, List<LevelEntry>>{};
  final uncategorized = <LevelEntry>[];
  for (final entry in entries) {
    final builtIn = entry.builtIn;
    final category = builtIn == null ? null : iartCourseCategoryOf(builtIn);
    if (category == null) {
      uncategorized.add(entry);
    } else {
      (byCategory[category] ??= []).add(entry);
    }
  }
  return (byCategory: byCategory, uncategorized: uncategorized);
}

/// [groupLevelEntriesByIartCategory] over the IART agency's full catalog
/// (ladder and specialties combined), for a screen that just wants "IART's
/// levels, grouped" without composing the catalog lookups itself.
({
  Map<IartCourseCategory, List<LevelEntry>> byCategory,
  List<LevelEntry> uncategorized,
})
groupIartCatalog(CertificationCatalog catalog) {
  final agencyId = CertificationAgency.iart.name;
  return groupLevelEntriesByIartCategory([
    ...catalog.ladderFor(agencyId),
    ...catalog.specialtiesFor(agencyId),
  ]);
}
