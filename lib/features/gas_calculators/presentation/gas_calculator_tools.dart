import 'package:flutter/material.dart';

import 'package:submersion/features/planning/presentation/planning_tools.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Path the six calculators hang off, and the page that lists them.
const String kGasCalculatorsRoutePrefix = '/planning/$kGasCalculatorsToolId';

/// Ids of the six calculators, in display order.
///
/// Shared by the router, the detail page, and the tests so a new calculator
/// cannot be added to the list and forgotten in the switch.
const List<String> kGasCalculatorIds = [
  'mod',
  'best-mix',
  'consumption',
  'rock-bottom',
  'mnd',
  'blender',
];

/// The six gas calculators, in display order.
///
/// These are [PlanningTool]s rather than a type of their own: they are listed
/// and rendered by the same tile as the Planning hub's tools, which is the
/// point. Gas Calculators is a hub one level down, and it should look like
/// one rather than merely resemble one.
///
/// Icons are the ones the tabs used, so a diver arriving from the old layout
/// recognises each calculator by its glyph.
List<PlanningTool> gasCalculatorToolsOf(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  PlanningTool tool({
    required String id,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) => PlanningTool(
    id: id,
    icon: icon,
    color: color,
    title: title,
    subtitle: subtitle,
    routePrefix: kGasCalculatorsRoutePrefix,
  );

  return [
    tool(
      id: 'mod',
      icon: Icons.arrow_downward,
      color: colorScheme.primary,
      title: context.l10n.gasCalculators_tab_mod,
      subtitle: context.l10n.gasCalculators_desc_mod,
    ),
    tool(
      id: 'best-mix',
      icon: Icons.science,
      color: colorScheme.tertiary,
      title: context.l10n.gasCalculators_tab_bestMix,
      subtitle: context.l10n.gasCalculators_desc_bestMix,
    ),
    tool(
      id: 'consumption',
      icon: Icons.local_gas_station,
      color: colorScheme.secondary,
      title: context.l10n.gasCalculators_tab_consumption,
      subtitle: context.l10n.gasCalculators_desc_consumption,
    ),
    tool(
      id: 'rock-bottom',
      icon: Icons.warning_amber,
      color: colorScheme.error,
      title: context.l10n.gasCalculators_tab_rockBottom,
      subtitle: context.l10n.gasCalculators_desc_rockBottom,
    ),
    tool(
      id: 'mnd',
      icon: Icons.psychology,
      color: Colors.teal,
      title: context.l10n.gasCalculators_tab_mnd,
      subtitle: context.l10n.gasCalculators_desc_mnd,
    ),
    tool(
      id: 'blender',
      icon: Icons.gas_meter,
      color: colorScheme.primary.withValues(alpha: 0.8),
      title: context.l10n.gasCalculators_tab_blender,
      subtitle: context.l10n.gasCalculators_desc_blender,
    ),
  ];
}
