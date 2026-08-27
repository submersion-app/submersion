import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planning/presentation/planning_tools.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// The Planning hub list: the planner with its recent saved plans, then the
/// calculators.
///
/// Rendered on its own on narrow windows, and as the master pane of the
/// Planning split view on desktop. [onToolSelected] is supplied only in the
/// second case; when it is null every row navigates as a full page, which is
/// the behaviour the hub has always had.
class PlanningListContent extends ConsumerWidget {
  const PlanningListContent({
    super.key,
    this.onToolSelected,
    this.selectedId,
    this.showAppBar = true,
  });

  /// Called with a tool id when a tool row is tapped in split view.
  final void Function(String?)? onToolSelected;

  /// Tool currently shown in the detail pane, highlighted in the list.
  final String? selectedId;

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final tools = planningToolsOf(context);

    final list = ListView(
      children: [
        const SizedBox(height: 8),
        _PlannerSection(onToolSelected: onToolSelected),
        const SizedBox(height: 8),
        _SectionLabel(context.l10n.planning_section_tools),
        ...List.generate(tools.length * 2 - 1, (index) {
          if (index.isOdd) return const Divider(height: 1);
          final tool = tools[index ~/ 2];
          return PlanningTile(
            tool: tool,
            selected: tool.id == selectedId,
            onToolSelected: onToolSelected,
          );
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
    );

    if (!showAppBar) return list;

    return Scaffold(
      appBar: AppBar(
        title: FeatureAppBarTitle(
          featureId: 'planning',
          title: context.l10n.planning_appBar_title,
        ),
      ),
      body: list,
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
  const _PlannerSection({this.onToolSelected});

  final void Function(String?)? onToolSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final summaries = ref.watch(divePlanSummariesProvider).valueOrNull;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final recent = summaries?.take(3).toList() ?? const [];

    return Column(
      children: [
        PlanningTile(
          tool: PlanningTool(
            id: kDivePlannerToolId,
            icon: Icons.edit_calendar,
            color: colorScheme.primary,
            title: context.l10n.planning_card_divePlanner_title,
            subtitle: context.l10n.planning_card_divePlanner_subtitle,
          ),
          // Never routed into the pane, even in split view: the planner has
          // its own three-pane layout and needs the full window.
          onToolSelected: null,
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
              onTap: () => context.push('/planning/dive-planner/${summary.id}'),
            ),
      ],
    );
  }
}

/// A compact list tile for a planning tool, matching the Statistics page style.
class PlanningTile extends StatelessWidget {
  const PlanningTile({
    super.key,
    required this.tool,
    this.selected = false,
    this.onToolSelected,
  });

  final PlanningTool tool;
  final bool selected;
  final void Function(String?)? onToolSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '${tool.title}, ${tool.subtitle}',
      child: ListTile(
        selected: selected,
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
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
        onTap: onToolSelected != null
            ? () => onToolSelected!(tool.id)
            // PUSH (not go): tools are sub-pages of the planning hub and must
            // stay poppable (#647).
            : () => context.push(tool.route),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
