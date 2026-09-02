import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// How a planning tool opens when its row is tapped.
///
/// The three cases differ in more than layout: they differ in the navigation
/// verb, and getting that wrong is visible. See [splitViewPage].
enum PlanningToolPresentation {
  /// Opens in the Planning detail pane on desktop, as a pushed page below the
  /// master-detail breakpoint. The default, and what most tools do.
  detailPane,

  /// Always takes the whole window, entered with `push`.
  ///
  /// For a tool whose own layout cannot be nested inside what is left beside
  /// a 440px master pane, and that drives no URL of its own once open. The
  /// dive planner is the example; it must stay poppable (#647).
  pushedPage,

  /// Always takes the whole window and hosts a [MasterDetailScaffold] of its
  /// own, entered with `go`.
  ///
  /// The `go` is load-bearing, not a style choice. A [MasterDetailScaffold]
  /// selects by calling `go`, which rebuilds the stack from the declarative
  /// route match and keys the page by its path. Entering on a `push` leaves
  /// the route carrying a generated key instead, so the first selection swaps
  /// one page for another and Flutter animates the whole page in from the
  /// right again, once, before settling. `go` on a nested child route still
  /// leaves the hub beneath it, so the tool stays poppable either way.
  splitViewPage,
}

/// A tool listed on the Planning hub.
class PlanningTool {
  /// Stable identifier, also the last path segment of [route] and the value
  /// carried in the detail pane's `?tool=` query parameter.
  final String id;

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  /// Path this tool's [id] hangs off.
  ///
  /// Defaults to the hub. Gas Calculators owns a second level of tools, so
  /// its six calculators pass `/planning/gas-calculators` and route under it.
  final String routePrefix;

  /// How this tool opens. See [PlanningToolPresentation].
  final PlanningToolPresentation presentation;

  const PlanningTool({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.routePrefix = '/planning',
    this.presentation = PlanningToolPresentation.detailPane,
  });

  String get route => '$routePrefix/$id';

  /// Whether this tool takes the whole window rather than the detail pane.
  bool get isFullPage => presentation != PlanningToolPresentation.detailPane;
}

/// Id of the dive planner.
///
/// The planner never opens in the detail pane: it has its own three-pane
/// layout (editor, chart, results) with thresholds at 760 and 1160px, and
/// squeezing that into what is left beside a 440px master pane would collapse
/// it to its narrowest form on all but enormous displays. It stays a
/// full-page push at every width.
///
/// Gas Calculators is the other tool in that position, for the same reason:
/// it renders its six calculators as a split view of its own. It says so with
/// [PlanningToolPresentation.splitViewPage] rather than by being rendered
/// separately, because unlike the planner it is an ordinary row in the tools
/// list, and it needs the other entry verb besides.
const String kDivePlannerToolId = 'dive-planner';

/// Id of the gas calculators hub, which owns a second level of tools.
const String kGasCalculatorsToolId = 'gas-calculators';

/// The calculators and readouts listed under the planner, in display order.
/// Each of these opens in the detail pane on desktop unless it declares
/// another [PlanningTool.presentation].
List<PlanningTool> planningToolsOf(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  return [
    PlanningTool(
      id: 'deco-calculator',
      icon: Icons.calculate,
      color: colorScheme.secondary,
      title: context.l10n.planning_card_decoCalculator_title,
      subtitle: context.l10n.planning_card_decoCalculator_subtitle,
    ),
    PlanningTool(
      id: kGasCalculatorsToolId,
      icon: Icons.science,
      color: colorScheme.tertiary,
      title: context.l10n.planning_card_gasCalculators_title,
      subtitle: context.l10n.planning_card_gasCalculators_subtitle,
      presentation: PlanningToolPresentation.splitViewPage,
    ),
    PlanningTool(
      id: 'weight-calculator',
      icon: Icons.fitness_center,
      color: colorScheme.primary.withValues(alpha: 0.8),
      title: context.l10n.planning_card_weightCalculator_title,
      subtitle: context.l10n.planning_card_weightCalculator_subtitle,
    ),
    PlanningTool(
      id: 'surface-interval',
      icon: Icons.timer,
      color: Colors.teal,
      title: context.l10n.planning_card_surfaceInterval_title,
      subtitle: context.l10n.planning_card_surfaceInterval_subtitle,
    ),
    PlanningTool(
      id: 'no-fly',
      icon: Icons.airplanemode_inactive,
      color: colorScheme.error,
      title: context.l10n.safetySettings_noFlyHeader,
      subtitle: context.l10n.planning_card_noFly_subtitle,
    ),
  ];
}
