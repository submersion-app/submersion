import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
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
