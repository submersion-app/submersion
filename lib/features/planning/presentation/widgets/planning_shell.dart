import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 900;

    if (!isWideScreen) {
      // Mobile/narrow: just show the child
      return child;
    }

    // Wide screen: master/detail layout
    return Scaffold(
      body: Row(
        children: [
          // Sidebar (master)
          SizedBox(width: 320, child: _PlanningSidebar()),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SidebarTile(
            icon: Icons.edit_calendar,
            iconColor: colorScheme.primary,
            title: 'Dive Planner',
            subtitle: 'Multi-level dive plans',
            isSelected: location.contains('/dive-planner'),
            onTap: () => context.go('/planning/dive-planner'),
          ),
          const SizedBox(height: 8),
          _SidebarTile(
            icon: Icons.calculate,
            iconColor: colorScheme.secondary,
            title: 'Deco Calculator',
            subtitle: 'NDL & deco stops',
            isSelected: location.contains('/deco-calculator'),
            onTap: () => context.go('/planning/deco-calculator'),
          ),
          const SizedBox(height: 8),
          _SidebarTile(
            icon: Icons.science,
            iconColor: colorScheme.tertiary,
            title: 'Gas Calculators',
            subtitle: 'MOD, Best Mix, more',
            isSelected: location.contains('/gas-calculators'),
            onTap: () => context.go('/planning/gas-calculators'),
          ),
          const SizedBox(height: 8),
          _SidebarTile(
            icon: Icons.fitness_center,
            iconColor: colorScheme.primary.withValues(alpha: 0.8),
            title: 'Weight Calculator',
            subtitle: 'Recommended weight',
            isSelected: location.contains('/weight-calculator'),
            onTap: () => context.go('/planning/weight-calculator'),
          ),
          const SizedBox(height: 8),
          _SidebarTile(
            icon: Icons.timer,
            iconColor: Colors.teal,
            title: 'Surface Interval',
            subtitle: 'Repetitive dive planning',
            isSelected: location.contains('/surface-interval'),
            onTap: () => context.go('/planning/surface-interval'),
          ),
          const SizedBox(height: 24),
          // Info card
          Card(
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
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Planning tools are for reference only. Always verify calculations.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact tile for the planning sidebar.
class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected ? colorScheme.primary : iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.8,
                              )
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onPrimaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
