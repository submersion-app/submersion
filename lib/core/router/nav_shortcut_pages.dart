import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/back_navigation.dart';
import 'package:submersion/core/router/shortcut_locations.dart';
import 'package:submersion/features/backup/presentation/pages/backup_settings_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_wallet_page.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/connections/presentation/pages/connections_page.dart';
import 'package:submersion/features/deco_calculator/presentation/pages/deco_calculator_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_map_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_map_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_list_page.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculator_detail_page.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculators_page.dart';
import 'package:submersion/features/import_wizard/presentation/pages/universal_import_wizard_route.dart';
import 'package:submersion/features/insights/presentation/pages/insights_conditions_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_equipment_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_gas_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_geographic_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_marine_life_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_observations_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_overview_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_profile_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_progression_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_social_page.dart';
import 'package:submersion/features/insights/presentation/pages/insights_time_patterns_page.dart';
import 'package:submersion/features/insights/presentation/pages/records_page.dart';
import 'package:submersion/features/maps/presentation/pages/dive_activity_map_page.dart';
import 'package:submersion/features/maps/presentation/pages/offline_maps_page.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_disclaimer_gate.dart';
import 'package:submersion/features/safety/presentation/pages/cns_otu_page.dart';
import 'package:submersion/features/safety/presentation/pages/emergency_card_page.dart';
import 'package:submersion/features/safety/presentation/pages/no_fly_page.dart';
import 'package:submersion/features/settings/presentation/pages/cloud_sync_page.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_hub_page.dart';
import 'package:submersion/features/surface_interval_tool/presentation/pages/surface_interval_tool_page.dart';
import 'package:submersion/features/weight_planner/presentation/pages/weight_planner_page.dart';
import 'package:submersion/shared/widgets/nav/nav_shortcuts.dart';

/// Builds a shortcut's page from the alias location's query parameters.
typedef NavShortcutPageBuilder = Widget Function(Map<String, String> query);

/// The page each nav shortcut opens, keyed by `NavShortcut.id`.
///
/// Each entry builds the same widget as the shortcut's canonical route, so
/// the page looks and behaves the same either way. The keys are held equal
/// to `kNavShortcuts` by `nav_shortcut_pages_test.dart`.
final Map<String, NavShortcutPageBuilder> kNavShortcutPages = Map.unmodifiable({
  // Planning.
  'dive-planner': (_) => const PlanCanvasPage(),
  'deco-calculator': (_) => const DecoCalculatorPage(),
  'gas-calculators': (_) => const GasCalculatorsPage(),
  'weight-calculator': (_) => const WeightPlannerPage(),
  'surface-interval': (_) => const SurfaceIntervalToolPage(),
  'no-fly': (_) => const NoFlyPage(),
  'cns-otu': (_) => const CnsOtuPage(),
  for (final calc in kGasCalculatorIds)
    'gas-$calc': (_) => GasCalculatorDetailPage(toolId: calc),

  // Insights.
  'insights-overview': (_) => const InsightsOverviewPage(),
  'insights-gas': (_) => const InsightsGasPage(),
  'insights-progression': (_) => const InsightsProgressionPage(),
  'insights-conditions': (_) => const InsightsConditionsPage(),
  'insights-social': (_) => const InsightsSocialPage(),
  'insights-geographic': (_) => const InsightsGeographicPage(),
  'insights-marine-life': (_) => const InsightsMarineLifePage(),
  'insights-time-patterns': (_) => const InsightsTimePatternsPage(),
  'insights-equipment': (_) => const InsightsEquipmentPage(),
  'insights-profile': (_) => const InsightsProfilePage(),
  'insights-observations': (_) => const InsightsObservationsPage(),
  'records': (_) => const RecordsPage(),
  'connections': (query) =>
      ConnectionsPage(args: ConnectionsRouteArgs.fromQuery(query)),

  // Views inside a section.
  'sites-map': (query) => SiteMapPage(
    initialSiteId: query['site'],
    initialScape3d: query['scape'] == '3d',
  ),
  'dive-activity-map': (_) => const DiveActivityMapPage(),
  'dive-centers-map': (_) => const DiveCenterMapPage(),
  'equipment-sets': (_) => const EquipmentSetListPage(),
  'certification-wallet': (_) => const CertificationWalletPage(),

  // Settings and tools.
  'emergency-card': (_) => const EmergencyCardPage(),
  'diver-profile': (_) => const DiverProfileHubPage(),
  'cloud-sync': (_) => const CloudSyncPage(),
  'backup': (_) => const BackupSettingsPage(),
  'offline-maps': (_) => const OfflineMapsPage(),
  'import-wizard': (_) => const UniversalImportWizardRoute(),
});

/// The alias route every nav shortcut opens on (#2936).
///
/// It has no parent route, so go_router builds the page as a one-page stack:
/// no back arrow, and system Back goes to the dashboard like any other
/// top-level tab (see `resolveUpLocation`). Planning pages keep the Planning
/// safety disclaimer. An id with no page (a stale bookmark, a hand-edited
/// URL) lands on the dashboard.
///
/// [pages] defaults to [kNavShortcutPages]; tests pass their own.
GoRoute navShortcutRoute({Map<String, NavShortcutPageBuilder>? pages}) {
  final resolved = pages ?? kNavShortcutPages;
  return GoRoute(
    path: '$kShortcutLocationPrefix/:id',
    redirect: (context, state) =>
        resolved.containsKey(state.pathParameters['id']) ? null : kRootLocation,
    pageBuilder: (context, state) {
      final id = state.pathParameters['id']!;
      final page = resolved[id]!(state.uri.queryParameters);
      final gated = navShortcutById(id)?.isPlanning ?? false;
      return NoTransitionPage(
        key: state.pageKey,
        child: gated ? PlanningDisclaimerGate(child: page) : page,
      );
    },
  );
}
