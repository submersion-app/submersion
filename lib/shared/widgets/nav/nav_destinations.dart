import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Canonical metadata for a single bottom-nav / nav-rail destination.
///
/// The `more` sentinel has [isPinned] `true` and [route] empty — it represents
/// the overflow control on phone, not a destination.
class NavDestination {
  const NavDestination({
    required this.id,
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.subtitle,
    this.isPinned = false,
  });

  /// Stable kebab-case identifier used for persistence.
  final String id;

  /// Path passed to `context.go(...)`. Empty string for the `more` sentinel.
  final String route;

  final IconData icon;
  final IconData selectedIcon;

  /// Returns the localized label for this destination.
  final String Function(AppLocalizations) label;

  /// Optional localized subtitle, used for Courses, Planning, and GPS Log.
  final String Function(AppLocalizations)? subtitle;

  /// When `true`, this destination cannot be moved between primary and overflow.
  final bool isPinned;
}

/// The complete, ordered list of nav destinations in default wide-screen order.
///
/// Length is **17**: 16 routable destinations plus the `more` sentinel.
final List<NavDestination> kNavDestinations = List.unmodifiable([
  NavDestination(
    id: 'dashboard',
    route: '/dashboard',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: (l10n) => l10n.nav_home,
    isPinned: true,
  ),
  NavDestination(
    id: 'dives',
    route: '/dives',
    icon: Icons.scuba_diving_outlined,
    selectedIcon: Icons.scuba_diving,
    label: (l10n) => l10n.nav_dives,
  ),
  NavDestination(
    id: 'sites',
    route: '/sites',
    icon: Icons.location_on_outlined,
    selectedIcon: Icons.location_on,
    label: (l10n) => l10n.nav_sites,
  ),
  NavDestination(
    id: 'trips',
    route: '/trips',
    icon: Icons.flight_outlined,
    selectedIcon: Icons.flight,
    label: (l10n) => l10n.nav_trips,
  ),
  NavDestination(
    id: 'media',
    route: '/media',
    icon: Icons.photo_library_outlined,
    selectedIcon: Icons.photo_library,
    label: (l10n) => l10n.nav_media,
  ),
  NavDestination(
    id: 'equipment',
    route: '/equipment',
    icon: Icons.backpack_outlined,
    selectedIcon: Icons.backpack,
    label: (l10n) => l10n.nav_equipment,
  ),
  NavDestination(
    id: 'buddies',
    route: '/buddies',
    icon: Icons.people_outlined,
    selectedIcon: Icons.people,
    label: (l10n) => l10n.nav_buddies,
  ),
  NavDestination(
    id: 'dive-centers',
    route: '/dive-centers',
    icon: Icons.store_outlined,
    selectedIcon: Icons.store,
    label: (l10n) => l10n.nav_diveCenters,
  ),
  NavDestination(
    id: 'certifications',
    route: '/certifications',
    icon: Icons.card_membership_outlined,
    selectedIcon: Icons.card_membership,
    label: (l10n) => l10n.nav_certifications,
  ),
  NavDestination(
    id: 'courses',
    route: '/courses',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    label: (l10n) => l10n.nav_courses,
    subtitle: (l10n) => l10n.nav_coursesSubtitle,
  ),
  // Species closes the logging-and-training run that precedes the analysis
  // surfaces: it is a record of what dives turned up, so it reads last before
  // Statistics. Material has no fish glyph, so this borrows MDI's and reuses
  // it for the selected state the way `gps-log` reuses its icon.
  NavDestination(
    id: 'species',
    route: '/species',
    icon: MdiIcons.fish,
    selectedIcon: MdiIcons.fish,
    label: (l10n) => l10n.nav_species,
  ),
  NavDestination(
    id: 'statistics',
    route: '/statistics',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    label: (l10n) => l10n.nav_statistics,
  ),
  NavDestination(
    id: 'planning',
    route: '/planning',
    icon: Icons.edit_calendar_outlined,
    selectedIcon: Icons.edit_calendar,
    label: (l10n) => l10n.nav_planning,
    subtitle: (l10n) => l10n.nav_planningSubtitle,
  ),
  NavDestination(
    id: 'transfer',
    route: '/transfer',
    icon: Icons.sync_alt_outlined,
    selectedIcon: Icons.sync_alt,
    label: (l10n) => l10n.nav_transfer,
  ),
  NavDestination(
    id: 'gps-log',
    route: '/gps-log',
    icon: Icons.gps_fixed,
    selectedIcon: Icons.gps_fixed,
    label: (l10n) => l10n.nav_gpsLog,
    subtitle: (l10n) => l10n.tools_gpsLogger_subtitle,
  ),
  NavDestination(
    id: 'settings',
    route: '/settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: (l10n) => l10n.nav_settings,
  ),
  NavDestination(
    id: 'more',
    route: '',
    icon: Icons.more_horiz_outlined,
    selectedIcon: Icons.more_horiz,
    label: (l10n) => l10n.nav_more,
    isPinned: true,
  ),
]);

/// The ids that can be moved between primary slots and overflow.
final List<String> movableNavIds = List.unmodifiable(
  kNavDestinations.where((d) => !d.isPinned).map((d) => d.id),
);

/// Number of customizable slots between Home and More in the phone bottom bar.
const int kPhonePrimarySlotCount = 3;

/// Default order for both nav surfaces: every movable id in canonical order.
///
/// On phone the first [kPhonePrimarySlotCount] entries are the bottom-bar
/// slots and the tail is the More sheet; on wide screens the whole list is the
/// rail, below the pinned Home destination.
final List<String> kDefaultNavOrder = movableNavIds;

/// Default primary middle-slot ids (slots 2, 3, 4).
final List<String> kDefaultPrimaryIds = List.unmodifiable(
  kDefaultNavOrder.take(kPhonePrimarySlotCount),
);

/// Normalizes a stored nav order into a complete, ordered list of movable ids.
///
/// Guarantees on the returned list:
/// - It contains every id in [movableIds] exactly once, so no destination can
///   be stranded by a partial or corrupt stored value.
/// - Ids present in [stored] come first, in stored order.
/// - Unknown and pinned ids are dropped; a duplicate keeps its first position.
/// - Everything else is appended in [movableIds] (canonical) order.
///
/// Values written before the order was widened held only the three phone
/// bottom-bar slots. Those normalize to the front, so an upgrading user keeps
/// the exact bottom bar they had and the rest of the order falls back to
/// canonical. The widened value stays readable by an older build too, since
/// that build takes its own first three ids.
List<String> normalizeNavOrder({
  required List<String> stored,
  required List<String> movableIds,
}) {
  final result = <String>[];
  for (final id in stored) {
    if (!movableIds.contains(id)) continue;
    if (result.contains(id)) continue;
    result.add(id);
  }

  for (final id in movableIds) {
    if (!result.contains(id)) result.add(id);
  }

  return List.unmodifiable(result);
}
