import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Shell widget that provides master/detail layout for Planning section.
///
/// On wide screens (>=900px), displays a sidebar with planning tools
/// navigation on the left and the selected tool content on the right.
/// On narrow screens, only displays the child content.
class PlanningShell extends StatelessWidget {
  final Widget child;

  const PlanningShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isWideScreen = ResponsiveBreakpoints.isMasterDetail(context);

    if (!isWideScreen) {
      // Mobile/narrow: just show the child
      return child;
    }

    // Wide screen: master/detail layout
    return Scaffold(
      body: Row(
        children: [
          // Sidebar (master)
          SizedBox(width: 440, child: _PlanningSidebar()),
          const VerticalDivider(width: 1, thickness: 1),
          // Content (detail)
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Sidebar navigation for Planning section.
class _PlanningSidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final location = GoRouterState.of(context).uri.path;

    final tools = [
      _SidebarItem(
        icon: Icons.edit_calendar,
        iconColor: colorScheme.primary,
        title: context.l10n.planning_sidebar_divePlanner_title,
        subtitle: context.l10n.planning_sidebar_divePlanner_subtitle,
        isSelected: location.contains('/dive-planner'),
        route: '/planning/dive-planner',
      ),
      _SidebarItem(
        icon: Icons.calculate,
        iconColor: colorScheme.secondary,
        title: context.l10n.planning_sidebar_decoCalculator_title,
        subtitle: context.l10n.planning_sidebar_decoCalculator_subtitle,
        isSelected: location.contains('/deco-calculator'),
        route: '/planning/deco-calculator',
      ),
      _SidebarItem(
        icon: Icons.science,
        iconColor: colorScheme.tertiary,
        title: context.l10n.planning_sidebar_gasCalculators_title,
        subtitle: context.l10n.planning_sidebar_gasCalculators_subtitle,
        isSelected: location.contains('/gas-calculators'),
        route: '/planning/gas-calculators',
      ),
      _SidebarItem(
        icon: Icons.fitness_center,
        iconColor: colorScheme.primary.withValues(alpha: 0.8),
        title: context.l10n.planning_sidebar_weightCalculator_title,
        subtitle: context.l10n.planning_sidebar_weightCalculator_subtitle,
        isSelected: location.contains('/weight-calculator'),
        route: '/planning/weight-calculator',
      ),
      _SidebarItem(
        icon: Icons.timer,
        iconColor: Colors.teal,
        title: context.l10n.planning_sidebar_surfaceInterval_title,
        subtitle: context.l10n.planning_sidebar_surfaceInterval_subtitle,
        isSelected: location.contains('/surface-interval'),
        route: '/planning/surface-interval',
      ),
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8, height: 40),
              Text(
                context.l10n.planning_sidebar_appBar_title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              const SizedBox(height: 8),
              ...List.generate(tools.length * 2 - 1, (index) {
                if (index.isOdd) return const Divider(height: 1);
                final tool = tools[index ~/ 2];
                return _SidebarTile(item: tool);
              }),
              const Divider(height: 1),
              const SizedBox(height: 16),
              // Info card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Card(
                  color: colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ).excludeFromSemantics(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.planning_sidebar_info_disclaimer,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

/// Data for a sidebar navigation item.
class _SidebarItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final String route;

  const _SidebarItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.route,
  });
}

/// A compact list tile for the planning sidebar, matching the Statistics style.
class _SidebarTile extends StatelessWidget {
  final _SidebarItem item;

  const _SidebarTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = item.isSelected ? colorScheme.primary : item.iconColor;

    return Semantics(
      button: true,
      label: '${item.title}, ${item.subtitle}',
      selected: item.isSelected,
      child: ListTile(
        selected: item.isSelected,
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
        leading: ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.isSelected
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: iconColor, size: 24),
          ),
        ),
        title: Text(
          item.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          item.subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: ExcludeSemantics(
          child: Icon(
            Icons.chevron_right,
            color: item.isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () => context.go(item.route),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
