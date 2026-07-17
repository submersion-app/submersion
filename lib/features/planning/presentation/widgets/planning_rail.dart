import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The 52px icon rail shown beside an open Planning tool on wide screens.
/// Replaces the 440px master sidebar so the tool gets the window.
class PlanningRail extends StatelessWidget {
  const PlanningRail({super.key, required this.currentPath});

  static const double width = 52;

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (
        icon: Icons.edit_calendar,
        tooltip: context.l10n.planning_sidebar_divePlanner_title,
        route: '/planning/dive-planner',
      ),
      (
        icon: Icons.calculate,
        tooltip: context.l10n.planning_sidebar_decoCalculator_title,
        route: '/planning/deco-calculator',
      ),
      (
        icon: Icons.science,
        tooltip: context.l10n.planning_sidebar_gasCalculators_title,
        route: '/planning/gas-calculators',
      ),
      (
        icon: Icons.fitness_center,
        tooltip: context.l10n.planning_sidebar_weightCalculator_title,
        route: '/planning/weight-calculator',
      ),
      (
        icon: Icons.timer,
        tooltip: context.l10n.planning_sidebar_surfaceInterval_title,
        route: '/planning/surface-interval',
      ),
    ];

    return Container(
      width: width,
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: context.l10n.planning_appBar_title,
            onPressed: () => context.go('/planning'),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _RailButton(
                icon: item.icon,
                tooltip: item.tooltip,
                selected: currentPath.startsWith(item.route),
                onPressed: () => context.go(item.route),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
