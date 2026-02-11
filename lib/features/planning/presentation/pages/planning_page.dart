import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Planning hub page displaying all dive planning tools.
///
/// Provides easy navigation to:
/// - Dive Planner: Create multi-level dive plans with gas switching
/// - Deco Calculator: Calculate NDL, deco stops, CNS/OTU exposure
/// - Gas Calculators: MOD, Best Mix, Consumption, Rock Bottom
/// - Weight Calculator: Recommended dive weight based on equipment
class PlanningPage extends StatelessWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.planning_appBar_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dive Planner Card
          _PlanningCard(
            icon: Icons.edit_calendar,
            iconColor: colorScheme.primary,
            title: context.l10n.planning_card_divePlanner_title,
            subtitle: context.l10n.planning_card_divePlanner_subtitle,
            description: context.l10n.planning_card_divePlanner_description,
            onTap: () => context.go('/planning/dive-planner'),
          ),
          const SizedBox(height: 12),

          // Deco Calculator Card
          _PlanningCard(
            icon: Icons.calculate,
            iconColor: colorScheme.secondary,
            title: context.l10n.planning_card_decoCalculator_title,
            subtitle: context.l10n.planning_card_decoCalculator_subtitle,
            description: context.l10n.planning_card_decoCalculator_description,
            onTap: () => context.go('/planning/deco-calculator'),
          ),
          const SizedBox(height: 12),

          // Gas Calculators Card
          _PlanningCard(
            icon: Icons.science,
            iconColor: colorScheme.tertiary,
            title: context.l10n.planning_card_gasCalculators_title,
            subtitle: context.l10n.planning_card_gasCalculators_subtitle,
            description: context.l10n.planning_card_gasCalculators_description,
            onTap: () => context.go('/planning/gas-calculators'),
          ),
          const SizedBox(height: 12),

          // Weight Calculator Card
          _PlanningCard(
            icon: Icons.fitness_center,
            iconColor: colorScheme.primary.withValues(alpha: 0.8),
            title: context.l10n.planning_card_weightCalculator_title,
            subtitle: context.l10n.planning_card_weightCalculator_subtitle,
            description:
                context.l10n.planning_card_weightCalculator_description,
            onTap: () => context.go('/planning/weight-calculator'),
          ),
          const SizedBox(height: 12),

          // Surface Interval Tool Card
          _PlanningCard(
            icon: Icons.timer,
            iconColor: Colors.teal,
            title: context.l10n.planning_card_surfaceInterval_title,
            subtitle: context.l10n.planning_card_surfaceInterval_subtitle,
            description: context.l10n.planning_card_surfaceInterval_description,
            onTap: () => context.go('/planning/surface-interval'),
          ),
          const SizedBox(height: 24),

          // Info Card
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.info_outline,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.planning_info_disclaimer,
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

/// A card widget displaying a planning tool with icon, title, description and tap action.
class _PlanningCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onTap;

  const _PlanningCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: '$title: $subtitle',
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 28, color: iconColor),
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
