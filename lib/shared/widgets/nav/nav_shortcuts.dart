import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/router/shortcut_locations.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// Where a shortcut is listed in the Add shortcut picker.
enum NavShortcutGroup { planning, insights, views, settingsAndTools }

/// A page below a top-level section that a diver can put on the main nav
/// (#2936).
///
/// A shortcut is stored in a nav order as [navShortcutOrderId] and rendered
/// through [navShortcutDestination]. Its page is built by the alias route,
/// `/shortcut/<id>` (see `nav_shortcut_pages.dart`), which keeps the page
/// builders out of this file so the catalog imports no feature pages.
class NavShortcut {
  const NavShortcut({
    required this.id,
    required this.group,
    required this.icon,
    required this.label,
    required this.parentLabel,
    required this.canonicalPath,
    required this.accent,
    this.navLabel,
    this.selection,
  });

  /// Stable kebab-case id, persisted inside the nav orders. Never rename one;
  /// a stored id the catalog no longer knows is dropped from the nav.
  final String id;

  final NavShortcutGroup group;
  final IconData icon;

  /// The page's name, as the Add shortcut picker lists it.
  final String Function(AppLocalizations) label;

  /// A shorter name for the nav itself, for a page whose [label] is wider
  /// than one bottom-bar slot. Null when [label] already fits.
  final String Function(AppLocalizations)? navLabel;

  /// The page's immediate parent, shown as a subtitle in the picker, the
  /// navigation editor and the More sheet.
  final String Function(AppLocalizations) parentLabel;

  /// The page's real location. The shortcut stays selected on it, and on
  /// anything below it.
  final String canonicalPath;

  /// The built-in nav id whose accent colors this shortcut's icon.
  final String accent;

  /// The desktop master-detail form of this page, when it has one.
  final NavSelectionMatch? selection;

  /// Whether the page sits behind the Planning safety disclaimer.
  bool get isPlanning => group == NavShortcutGroup.planning;
}

NavShortcut _planningTool(
  String id,
  IconData icon,
  String Function(AppLocalizations) label, {
  String Function(AppLocalizations)? navLabel,
  bool inDetailPane = true,
}) => NavShortcut(
  id: id,
  group: NavShortcutGroup.planning,
  icon: icon,
  label: label,
  navLabel: navLabel,
  parentLabel: (l10n) => l10n.nav_planning,
  canonicalPath: '/planning/$id',
  accent: 'planning',
  selection: inDetailPane
      ? NavSelectionMatch(path: '/planning', queryKey: 'tool', queryValue: id)
      : null,
);

NavShortcut _gasCalculator(
  String calc,
  IconData icon,
  String Function(AppLocalizations) label, {
  String Function(AppLocalizations)? navLabel,
}) => NavShortcut(
  id: 'gas-$calc',
  group: NavShortcutGroup.planning,
  icon: icon,
  label: label,
  navLabel: navLabel,
  parentLabel: (l10n) => l10n.planning_card_gasCalculators_title,
  canonicalPath: '/planning/gas-calculators/$calc',
  accent: 'planning',
  selection: NavSelectionMatch(
    path: '/planning/gas-calculators',
    queryKey: 'calc',
    queryValue: calc,
  ),
);

NavShortcut _insightsPage(
  String page,
  IconData icon,
  String Function(AppLocalizations) label, {
  String Function(AppLocalizations)? navLabel,
}) => NavShortcut(
  id: 'insights-$page',
  group: NavShortcutGroup.insights,
  icon: icon,
  label: label,
  navLabel: navLabel,
  parentLabel: (l10n) => l10n.nav_insights,
  canonicalPath: '/insights/$page',
  accent: 'insights',
  selection: NavSelectionMatch(
    path: '/insights',
    queryKey: 'selected',
    queryValue: page,
  ),
);

/// Every shortcut, in picker order within each group.
final List<NavShortcut> kNavShortcuts = List.unmodifiable([
  // Planning. The dive planner and the gas calculators hub always take the
  // whole window, so neither has a detail-pane form.
  _planningTool(
    'dive-planner',
    Icons.edit_calendar,
    (l10n) => l10n.planning_card_divePlanner_title,
    inDetailPane: false,
  ),
  _planningTool(
    'deco-calculator',
    Icons.calculate,
    (l10n) => l10n.planning_card_decoCalculator_title,
    navLabel: (l10n) => l10n.navShortcut_short_deco,
  ),
  _planningTool(
    'gas-calculators',
    Icons.science,
    (l10n) => l10n.planning_card_gasCalculators_title,
    inDetailPane: false,
    navLabel: (l10n) => l10n.navShortcut_short_gasCalculators,
  ),
  _planningTool(
    'weight-calculator',
    Icons.fitness_center,
    (l10n) => l10n.planning_card_weightCalculator_title,
    navLabel: (l10n) => l10n.navShortcut_short_weighting,
  ),
  _planningTool(
    'surface-interval',
    Icons.timer,
    (l10n) => l10n.planning_card_surfaceInterval_title,
    navLabel: (l10n) => l10n.navShortcut_short_surfaceInterval,
  ),
  _planningTool(
    'no-fly',
    Icons.airplanemode_inactive,
    (l10n) => l10n.navShortcut_noFly,
  ),
  _planningTool('cns-otu', Icons.air, (l10n) => l10n.navShortcut_cnsOtu),
  _gasCalculator(
    'mod',
    Icons.arrow_downward,
    (l10n) => l10n.gasCalculators_tab_mod,
  ),
  _gasCalculator(
    'best-mix',
    Icons.science,
    (l10n) => l10n.gasCalculators_tab_bestMix,
  ),
  _gasCalculator(
    'consumption',
    Icons.local_gas_station,
    (l10n) => l10n.gasCalculators_tab_consumption,
  ),
  _gasCalculator(
    'rock-bottom',
    Icons.warning_amber,
    (l10n) => l10n.gasCalculators_tab_rockBottom,
  ),
  _gasCalculator(
    'mnd',
    Icons.psychology,
    (l10n) => l10n.gasCalculators_tab_mnd,
  ),
  _gasCalculator(
    'icd',
    Icons.compare_arrows,
    (l10n) => l10n.gasCalculators_tab_icd,
  ),
  _gasCalculator(
    'density',
    Icons.compress,
    (l10n) => l10n.gasCalculators_tab_density,
  ),
  _gasCalculator(
    'blender',
    Icons.gas_meter,
    (l10n) => l10n.gasCalculators_tab_blender,
    navLabel: (l10n) => l10n.navShortcut_short_blender,
  ),

  // Insights.
  _insightsPage(
    'overview',
    Icons.dashboard_outlined,
    (l10n) => l10n.insights_category_overview_title,
  ),
  _insightsPage(
    'gas',
    Icons.air,
    (l10n) => l10n.insights_category_gas_title,
    navLabel: (l10n) => l10n.navShortcut_short_airUse,
  ),
  _insightsPage(
    'progression',
    Icons.trending_up,
    (l10n) => l10n.insights_category_progression_title,
  ),
  _insightsPage(
    'conditions',
    Icons.thermostat,
    (l10n) => l10n.insights_category_conditions_title,
  ),
  _insightsPage(
    'social',
    Icons.people,
    (l10n) => l10n.insights_category_social_title,
  ),
  _insightsPage(
    'geographic',
    Icons.public,
    (l10n) => l10n.insights_category_geographic_title,
  ),
  _insightsPage(
    'marine-life',
    MdiIcons.fish,
    (l10n) => l10n.insights_category_marineLife_title,
    navLabel: (l10n) => l10n.navShortcut_short_speciesStats,
  ),
  _insightsPage(
    'time-patterns',
    Icons.schedule,
    (l10n) => l10n.insights_category_timePatterns_title,
    navLabel: (l10n) => l10n.navShortcut_short_patterns,
  ),
  _insightsPage(
    'equipment',
    Icons.build,
    (l10n) => l10n.insights_category_equipment_title,
    navLabel: (l10n) => l10n.navShortcut_short_gearStats,
  ),
  _insightsPage(
    'profile',
    Icons.show_chart,
    (l10n) => l10n.insights_category_profile_title,
    navLabel: (l10n) => l10n.navShortcut_short_profiles,
  ),
  _insightsPage(
    'observations',
    Icons.lightbulb_outline,
    (l10n) => l10n.insights_observations_title,
  ),
  NavShortcut(
    id: 'records',
    group: NavShortcutGroup.insights,
    icon: Icons.emoji_events,
    label: (l10n) => l10n.navShortcut_records,
    parentLabel: (l10n) => l10n.nav_insights,
    canonicalPath: '/records',
    accent: 'insights',
  ),
  NavShortcut(
    id: 'connections',
    group: NavShortcutGroup.insights,
    icon: Icons.hub_outlined,
    label: (l10n) => l10n.connections_title,
    parentLabel: (l10n) => l10n.nav_insights,
    canonicalPath: '/insights/connections',
    accent: 'insights',
  ),

  // Views inside a section.
  NavShortcut(
    id: 'sites-map',
    group: NavShortcutGroup.views,
    icon: Icons.map_outlined,
    label: (l10n) => l10n.navShortcut_sitesMap,
    parentLabel: (l10n) => l10n.nav_sites,
    canonicalPath: '/sites/map',
    accent: 'sites',
  ),
  NavShortcut(
    id: 'dive-activity-map',
    group: NavShortcutGroup.views,
    icon: Icons.public,
    label: (l10n) => l10n.navShortcut_diveActivityMap,
    navLabel: (l10n) => l10n.navShortcut_short_diveMap,
    parentLabel: (l10n) => l10n.nav_dives,
    canonicalPath: '/dives/activity',
    accent: 'dives',
  ),
  NavShortcut(
    id: 'dive-centers-map',
    group: NavShortcutGroup.views,
    icon: Icons.map,
    label: (l10n) => l10n.navShortcut_diveCentersMap,
    navLabel: (l10n) => l10n.navShortcut_short_centersMap,
    parentLabel: (l10n) => l10n.nav_diveCenters,
    canonicalPath: '/dive-centers/map',
    accent: 'dive-centers',
  ),
  NavShortcut(
    id: 'equipment-sets',
    group: NavShortcutGroup.views,
    icon: Icons.inventory_2_outlined,
    label: (l10n) => l10n.equipment_sets_appBar_title,
    navLabel: (l10n) => l10n.navShortcut_short_gearSets,
    parentLabel: (l10n) => l10n.nav_equipment,
    canonicalPath: '/equipment/sets',
    accent: 'equipment',
  ),
  NavShortcut(
    id: 'certification-wallet',
    group: NavShortcutGroup.views,
    icon: Icons.wallet,
    label: (l10n) => l10n.certifications_wallet_appBar_title,
    navLabel: (l10n) => l10n.navShortcut_short_certWallet,
    parentLabel: (l10n) => l10n.nav_certifications,
    canonicalPath: '/certifications/wallet',
    accent: 'certifications',
  ),

  // Settings and tools.
  NavShortcut(
    id: 'emergency-card',
    group: NavShortcutGroup.settingsAndTools,
    icon: Icons.emergency_outlined,
    label: (l10n) => l10n.dashboard_quickAction_emergency,
    navLabel: (l10n) => l10n.navShortcut_short_emergency,
    parentLabel: (l10n) => l10n.nav_settings,
    canonicalPath: '/settings/diver-profile/emergency-card',
    accent: 'settings',
  ),
  NavShortcut(
    id: 'diver-profile',
    group: NavShortcutGroup.settingsAndTools,
    icon: Icons.person_outline,
    label: (l10n) => l10n.navShortcut_diverProfile,
    parentLabel: (l10n) => l10n.nav_settings,
    canonicalPath: '/settings/diver-profile',
    accent: 'settings',
  ),
  NavShortcut(
    id: 'cloud-sync',
    group: NavShortcutGroup.settingsAndTools,
    icon: Icons.cloud_sync_outlined,
    label: (l10n) => l10n.navShortcut_cloudSync,
    parentLabel: (l10n) => l10n.nav_settings,
    canonicalPath: '/settings/cloud-sync',
    accent: 'settings',
  ),
  NavShortcut(
    id: 'backup',
    group: NavShortcutGroup.settingsAndTools,
    icon: Icons.backup_outlined,
    label: (l10n) => l10n.backup_appBar_title,
    navLabel: (l10n) => l10n.navShortcut_short_backup,
    parentLabel: (l10n) => l10n.nav_settings,
    canonicalPath: '/settings/backup',
    accent: 'settings',
  ),
  NavShortcut(
    id: 'offline-maps',
    group: NavShortcutGroup.settingsAndTools,
    icon: Icons.download_for_offline_outlined,
    label: (l10n) => l10n.navShortcut_offlineMaps,
    parentLabel: (l10n) => l10n.nav_settings,
    canonicalPath: '/settings/offline-maps',
    accent: 'settings',
  ),
  NavShortcut(
    id: 'import-wizard',
    group: NavShortcutGroup.settingsAndTools,
    icon: Icons.file_upload_outlined,
    label: (l10n) => l10n.universalImport_title,
    parentLabel: (l10n) => l10n.nav_transfer,
    canonicalPath: '/transfer/import-wizard',
    accent: 'transfer',
  ),
]);

/// Marks a nav order entry as a shortcut rather than a built-in id.
const String kNavShortcutIdPrefix = 'shortcut:';

/// The nav order entry for the catalog shortcut [shortcutId].
String navShortcutOrderId(String shortcutId) =>
    '$kNavShortcutIdPrefix$shortcutId';

final Map<String, NavShortcut> _byId = {for (final s in kNavShortcuts) s.id: s};

/// The catalog shortcut [id], or null when this build does not know it.
NavShortcut? navShortcutById(String id) => _byId[id];

/// The shortcut a nav order entry names, or null for a built-in id or a
/// shortcut this build does not know.
NavShortcut? navShortcutForOrderId(String orderId) =>
    orderId.startsWith(kNavShortcutIdPrefix)
    ? _byId[orderId.substring(kNavShortcutIdPrefix.length)]
    : null;

/// The nav order entry of every catalog shortcut.
final List<String> kNavShortcutOrderIds = List.unmodifiable(
  kNavShortcuts.map((s) => navShortcutOrderId(s.id)),
);

/// [shortcut] as a destination the rail, the bottom bar and the More sheet
/// render like any built-in.
NavDestination navShortcutDestination(NavShortcut shortcut) => NavDestination(
  id: navShortcutOrderId(shortcut.id),
  route: shortcutLocation(shortcut.id),
  icon: shortcut.icon,
  selectedIcon: shortcut.icon,
  label: shortcut.navLabel ?? shortcut.label,
  subtitle: shortcut.parentLabel,
  extraMatchPaths: [shortcut.canonicalPath],
  selection: shortcut.selection,
  accent: shortcut.accent,
);

/// The destination a nav order entry names: a shortcut, or one of
/// [builtInsById]. Null for an id neither knows.
NavDestination? resolveNavDestination(
  String orderId,
  Map<String, NavDestination> builtInsById,
) => _destinationsByOrderId[orderId] ?? builtInsById[orderId];

/// Every shortcut's destination, built once: they depend only on the catalog.
final Map<String, NavDestination> _destinationsByOrderId = {
  for (final s in kNavShortcuts)
    navShortcutOrderId(s.id): navShortcutDestination(s),
};
