import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Planning hub page: the planner (new plan + recent saved plans) front and
/// center, calculators as a tools list below.
class PlanningPage extends ConsumerWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final tools = _planningToolsOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.planning_appBar_title)),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const _PlannerSection(),
          const SizedBox(height: 8),
          _SectionLabel(context.l10n.planning_section_tools),
          ...List.generate(tools.length * 2 - 1, (index) {
            if (index.isOdd) return const Divider(height: 1);
            return _PlanningTile(tool: tools[index ~/ 2]);
          }),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Info disclaimer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.onSurfaceVariant,
                    ).excludeFromSemantics(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.planning_info_disclaimer,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
    );
  }
}

/// Section header matching the tools/plans grouping.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// The planner front and center: a tool row just like the others (the whole
/// row opens the planner), with the three most recently touched saved plans
/// beneath it.
class _PlannerSection extends ConsumerWidget {
  const _PlannerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final summaries = ref.watch(divePlanSummariesProvider).valueOrNull;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final recent = summaries?.take(3).toList() ?? const [];

    return Column(
      children: [
        _PlanningTile(
          tool: _PlanningTool(
            icon: Icons.edit_calendar,
            color: colorScheme.primary,
            title: context.l10n.planning_card_divePlanner_title,
            subtitle: context.l10n.planning_card_divePlanner_subtitle,
            route: '/planning/dive-planner',
          ),
        ),
        if (recent.isNotEmpty)
          for (final summary in recent)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 76, right: 16),
              dense: true,
              leading: const Icon(Icons.route, size: 20),
              title: Text(summary.name),
              subtitle: Text(
                [
                  if (summary.maxDepth != null)
                    units.formatDepth(summary.maxDepth!),
                  if (summary.runtimeSeconds != null)
                    '${(summary.runtimeSeconds! / 60).ceil()}′',
                  summary.mode.name.toUpperCase(),
                ].join(' · '),
              ),
              onTap: () => context.go('/planning/dive-planner/${summary.id}'),
            ),
      ],
    );
  }
}

/// Data class for a planning tool entry.
class _PlanningTool {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;

  const _PlanningTool({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

/// Builds the planning tools list from localized strings.
List<_PlanningTool> _planningToolsOf(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  return [
    _PlanningTool(
      icon: Icons.calculate,
      color: colorScheme.secondary,
      title: context.l10n.planning_card_decoCalculator_title,
      subtitle: context.l10n.planning_card_decoCalculator_subtitle,
      route: '/planning/deco-calculator',
    ),
    _PlanningTool(
      icon: Icons.science,
      color: colorScheme.tertiary,
      title: context.l10n.planning_card_gasCalculators_title,
      subtitle: context.l10n.planning_card_gasCalculators_subtitle,
      route: '/planning/gas-calculators',
    ),
    _PlanningTool(
      icon: Icons.fitness_center,
      color: colorScheme.primary.withValues(alpha: 0.8),
      title: context.l10n.planning_card_weightCalculator_title,
      subtitle: context.l10n.planning_card_weightCalculator_subtitle,
      route: '/planning/weight-calculator',
    ),
    _PlanningTool(
      icon: Icons.timer,
      color: Colors.teal,
      title: context.l10n.planning_card_surfaceInterval_title,
      subtitle: context.l10n.planning_card_surfaceInterval_subtitle,
      route: '/planning/surface-interval',
    ),
  ];
}

/// A compact list tile for a planning tool, matching the Statistics page style.
class _PlanningTile extends StatelessWidget {
  final _PlanningTool tool;

  const _PlanningTile({required this.tool});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: '${tool.title}, ${tool.subtitle}',
      child: ListTile(
        leading: ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tool.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tool.icon, color: tool.color, size: 24),
          ),
        ),
        title: Text(
          tool.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          tool.subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant,
        ).excludeFromSemantics(),
        onTap: () => context.go(tool.route),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
