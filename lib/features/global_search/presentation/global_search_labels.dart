import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A section's heading.
String globalSearchKindLabel(AppLocalizations l10n, GlobalSearchKind kind) =>
    switch (kind) {
      GlobalSearchKind.dives => l10n.nav_dives,
      GlobalSearchKind.sites => l10n.nav_sites,
      GlobalSearchKind.trips => l10n.nav_trips,
      GlobalSearchKind.equipment => l10n.nav_equipment,
      GlobalSearchKind.equipmentSets => l10n.equipment_sets_appBar_title,
      GlobalSearchKind.buddies => l10n.nav_buddies,
      GlobalSearchKind.diveCenters => l10n.nav_diveCenters,
      GlobalSearchKind.certifications => l10n.nav_certifications,
      GlobalSearchKind.courses => l10n.nav_courses,
      GlobalSearchKind.species => l10n.nav_species,
      GlobalSearchKind.documents => l10n.nav_documents,
      GlobalSearchKind.divePlans => l10n.planning_summary_savedPlans,
      GlobalSearchKind.gpsTracks => l10n.globalSearch_section_gpsTracks,
      GlobalSearchKind.underwaterRoutes =>
        l10n.globalSearch_section_underwaterRoutes,
    };

/// A section's icon, the one its section wears in the navigation.
IconData globalSearchKindIcon(GlobalSearchKind kind) => switch (kind) {
  GlobalSearchKind.dives => Icons.scuba_diving,
  GlobalSearchKind.sites => Icons.location_on,
  GlobalSearchKind.trips => Icons.flight,
  GlobalSearchKind.equipment => Icons.backpack,
  GlobalSearchKind.equipmentSets => Icons.inventory_2,
  GlobalSearchKind.buddies => Icons.people,
  GlobalSearchKind.diveCenters => Icons.store,
  GlobalSearchKind.certifications => Icons.card_membership,
  GlobalSearchKind.courses => Icons.school,
  GlobalSearchKind.species => MdiIcons.fish,
  GlobalSearchKind.documents => Icons.folder_copy,
  GlobalSearchKind.divePlans => Icons.edit_calendar,
  GlobalSearchKind.gpsTracks => Icons.route,
  GlobalSearchKind.underwaterRoutes => Icons.explore,
};

/// A result row's title: a dive leads with its number, a built-in species
/// with its name in the diver's language, and a record with no name of its
/// own with its date.
String globalSearchHitTitle(
  GlobalSearchHit hit,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  final title = hit.title ?? units.formatMonthDayWithYear(hit.date);
  return switch (hit.kind) {
    // An untitled document goes by its type, as it does everywhere else.
    GlobalSearchKind.documents when hit.title == null => documentTypeLabel(
      l10n,
      DocumentType.fromStorage(hit.type!),
    ),
    GlobalSearchKind.dives when hit.number != null =>
      l10n.diveLog_search_jumpNumberTitle(hit.number!, title),
    GlobalSearchKind.species => localizedSpeciesName(l10n, hit.id, title),
    _ => title,
  };
}

/// A result row's supporting line, or null when it has nothing to add: the
/// date is left out of a row whose title already is the date.
String? globalSearchHitSubtitle(
  GlobalSearchHit hit,
  AppLocalizations l10n,
  UnitFormatter units, {
  CertificationCatalog? catalog,
}) {
  final parts = [
    if (hit.date != null && hit.title != null)
      units.formatMonthDayWithYear(hit.date),
    if (hit.depthMeters != null) units.formatDepth(hit.depthMeters),
    for (final (i, detail) in hit.details.indexed)
      hit.kind == GlobalSearchKind.certifications && i == 0
          ? (catalog ?? CertificationCatalog.builtInOnly)
                .agency(detail)
                .localizedName(l10n)
          : detail,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
