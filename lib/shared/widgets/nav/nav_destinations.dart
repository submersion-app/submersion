import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/router/training_locations.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/nav/nav_id_aliases.dart';
import 'package:submersion/shared/widgets/nav/nav_slot_count.dart';

/// Fraction of the screen height a phone nav sheet (the More sheet, the Add
/// shortcut picker) may fill. The remainder is scrim the user can tap to
/// dismiss the sheet.
const double kNavSheetMaxHeightFraction = 0.85;

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
    this.extraMatchPaths = const [],
    this.selection,
    String? accent,
  }) : _accent = accent;

  /// Stable kebab-case identifier used for persistence.
  final String id;

  /// Path passed to `context.go(...)`. Empty string for the `more` sentinel.
  final String route;

  final IconData icon;
  final IconData selectedIcon;

  /// Returns the localized label for this destination.
  final String Function(AppLocalizations) label;

  /// Optional localized subtitle, used for Training, Planning, and Tracks.
  final String Function(AppLocalizations)? subtitle;

  /// When `true`, this destination cannot be moved between primary and overflow.
  final bool isPinned;

  /// Further locations this destination owns besides [route], each matched
  /// as a segment-aware path prefix. A nav shortcut lists its page's
  /// canonical path here, so it stays selected when the diver reaches that
  /// page by hand rather than through the shortcut.
  final List<String> extraMatchPaths;

  /// A desktop master-detail selection that shows this destination's page,
  /// such as `/planning?tool=deco-calculator`.
  final NavSelectionMatch? selection;

  final String? _accent;

  /// The id whose feature accent colors this destination's icon. A nav
  /// shortcut borrows the accent of the section its page belongs to.
  String get accentId => _accent ?? id;
}

/// A location shape that selects one item inside a master-detail page: the
/// page's [path] with [queryKey] set to [queryValue].
///
/// `/planning?tool=deco-calculator` is the Deco calculator in the Planning
/// detail pane, so a Deco shortcut owns that location even though its path
/// is Planning's.
class NavSelectionMatch {
  const NavSelectionMatch({
    required this.path,
    required this.queryKey,
    required this.queryValue,
  });

  final String path;
  final String queryKey;
  final String queryValue;
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
  // Training holds Certifications and Courses as two tabs (#3437). It sits
  // where Certifications did, since looking up a card is the common visit,
  // and its tabs keep their own addresses, which select it too.
  NavDestination(
    id: 'training',
    route: kTrainingLocation,
    extraMatchPaths: [
      TrainingTab.certifications.path,
      TrainingTab.courses.path,
    ],
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    label: (l10n) => l10n.nav_training,
    subtitle: (l10n) => l10n.nav_trainingSubtitle,
    accent: 'certifications',
  ),
  // Media sits with Documents: both are reference collections a diver
  // browses, rather than the logging sections at the top of the list.
  NavDestination(
    id: 'media',
    route: '/media',
    icon: Icons.photo_library_outlined,
    selectedIcon: Icons.photo_library,
    label: (l10n) => l10n.nav_media,
  ),
  NavDestination(
    id: 'documents',
    route: '/documents',
    icon: Icons.folder_copy_outlined,
    selectedIcon: Icons.folder_copy,
    label: (l10n) => l10n.nav_documents,
  ),
  // Species closes the logging-and-training run that precedes the analysis
  // surfaces: it is a record of what dives turned up, so it reads last before
  // Insights. Material has no fish glyph, so this borrows MDI's and reuses
  // it for the selected state.
  NavDestination(
    id: 'species',
    route: '/species',
    icon: MdiIcons.fish,
    selectedIcon: MdiIcons.fish,
    label: (l10n) => l10n.nav_species,
  ),
  NavDestination(
    id: 'insights',
    route: '/insights',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    label: (l10n) => l10n.nav_insights,
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
    id: 'tracks',
    route: kTracksLocation,
    icon: Icons.route_outlined,
    selectedIcon: Icons.route,
    label: (l10n) => l10n.nav_tracks,
    subtitle: (l10n) => l10n.nav_tracksSubtitle,
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

/// Default order for both nav surfaces: every movable id in canonical order.
///
/// On phone the first [kMinPhonePrimarySlotCount] entries are the guaranteed
/// bottom-bar slots (more may show on a wider screen, see
/// `phonePrimarySlotCount`) and the tail is the More sheet; on wide screens
/// the whole list is the rail, below the pinned Home destination.
final List<String> kDefaultNavOrder = movableNavIds;

/// Default primary middle-slot ids (slots 2, 3, 4).
final List<String> kDefaultPrimaryIds = List.unmodifiable(
  kDefaultNavOrder.take(kMinPhonePrimarySlotCount),
);

/// Normalizes a stored nav order into a complete, ordered list of movable ids.
///
/// Guarantees on the returned list:
/// - It contains every id in [movableIds] exactly once, so no destination can
///   be stranded by a partial or corrupt stored value.
/// - Ids present in [stored] come first, in stored order.
/// - An id this build does not know is first read through [kRenamedNavIds],
///   so a renamed destination keeps its slot. An alias never replaces an id
///   the build still knows.
/// - Unknown and pinned ids are dropped; a duplicate keeps its first position.
/// - Everything else is appended in [movableIds] (canonical) order.
/// - Entries in [shortcutOrderIds] (nav shortcuts, #2936) keep their stored
///   position. A shortcut this build does not know is dropped, and a missing
///   one is never appended: shortcuts are the diver's additions, not part of
///   the guaranteed set.
///
/// Values written before the order was widened held only the three phone
/// bottom-bar slots. Those normalize to the front, so an upgrading user keeps
/// the exact bottom bar they had and the rest of the order falls back to
/// canonical. The widened value stays readable by an older build too, since
/// that build takes its own first three ids.
List<String> normalizeNavOrder({
  required List<String> stored,
  required List<String> movableIds,
  Iterable<String> shortcutOrderIds = const [],
}) {
  final result = <String>[];
  for (final storedId in stored) {
    if (shortcutOrderIds.contains(storedId)) {
      if (!result.contains(storedId)) result.add(storedId);
      continue;
    }
    final id = movableIds.contains(storedId)
        ? storedId
        : kRenamedNavIds[storedId] ?? storedId;
    if (!movableIds.contains(id)) continue;
    if (result.contains(id)) continue;
    result.add(id);
  }

  for (final id in movableIds) {
    if (!result.contains(id)) result.add(id);
  }

  return List.unmodifiable(result);
}
