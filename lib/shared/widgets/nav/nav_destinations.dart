import 'package:flutter/material.dart';

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

  /// Optional localized subtitle, used for Courses and Planning.
  final String Function(AppLocalizations)? subtitle;

  /// When `true`, this destination cannot be moved between primary and overflow.
  final bool isPinned;
}

/// The complete, ordered list of nav destinations in default wide-screen order.
///
/// Length is **14** — 13 routable destinations plus the `more` sentinel.
final List<NavDestination> kNavDestinations = [
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
];

/// The 12 ids that can be moved between primary slots and overflow.
final List<String> movableNavIds = kNavDestinations
    .where((d) => !d.isPinned)
    .map((d) => d.id)
    .toList(growable: false);

/// Default primary middle-slot ids (slots 2, 3, 4). Matches pre-customization behavior.
const List<String> kDefaultPrimaryIds = ['dives', 'sites', 'trips'];

/// Normalizes a stored list of primary ids into a valid 3-element list.
///
/// Guarantees on the returned list:
/// - Length is exactly 3.
/// - Every id is in [movableIds] (unknown / pinned ids are dropped).
/// - No duplicates (first occurrence wins).
/// - Padding uses [defaults] in order, skipping already-present ids.
///
/// [defaults] must contain at least 3 ids from [movableIds]; otherwise this
/// throws [ArgumentError]. Callers should pass [kDefaultPrimaryIds].
List<String> normalizeNavPrimaryIds({
  required List<String> stored,
  required List<String> movableIds,
  required List<String> defaults,
}) {
  assert(defaults.length >= 3, 'defaults must contain at least 3 ids');
  for (final id in defaults.take(3)) {
    if (!movableIds.contains(id)) {
      throw ArgumentError('default id "$id" not in movableIds');
    }
  }

  final result = <String>[];
  for (final id in stored) {
    if (result.length == 3) break;
    if (!movableIds.contains(id)) continue;
    if (result.contains(id)) continue;
    result.add(id);
  }

  for (final id in defaults) {
    if (result.length == 3) break;
    if (!result.contains(id)) result.add(id);
  }

  return List.unmodifiable(result);
}
