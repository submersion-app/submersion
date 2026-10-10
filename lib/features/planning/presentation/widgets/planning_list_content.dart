import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planning/presentation/planning_tools.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';
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
    final recentPlans =
        ref.watch(divePlanSummariesProvider).valueOrNull?.take(3).toList() ??
        const [];

    final list = KeyboardListNavigator(
      keys: [
        kDivePlannerToolId,
        for (final plan in recentPlans) _planNavKey(plan.id),
        for (final tool in tools) tool.id,
      ],
      currentKey: selectedId,
      onMove: (id) {
        final tool = tools.where((t) => t.id == id).firstOrNull;
        // The planner and saved plans open full pages, so they wait for Enter.
        if (tool == null) return;
        moveListCursor(
          context,
          canOpen: !tool.isFullPage && onToolSelected != null,
          open: () => onToolSelected!(id),
          highlight: () {},
        );
      },
      onActivate: (id) {
        if (id == kDivePlannerToolId) {
          PlanningTile.select(context, _plannerTool(context), null);
          return;
        }
        final plan = recentPlans
            .where((p) => _planNavKey(p.id) == id)
            .firstOrNull;
        if (plan != null) {
          _openPlan(context, plan.id);
          return;
        }
        PlanningTile.select(
          context,
          tools.firstWhere((t) => t.id == id),
          onToolSelected,
        );
      },
      child: ListView(
        children: [
          const SizedBox(height: 8),
          _PlannerSection(recentPlans: recentPlans),
          const SizedBox(height: 8),
          _SectionLabel(context.l10n.planning_section_tools),
          ...List.generate(tools.length * 2 - 1, (index) {
            if (index.isOdd) return const Divider(height: 1);
            final tool = tools[index ~/ 2];
            return KeyboardListItem(
              navigationKey: tool.id,
              child: PlanningTile(
                tool: tool,
                selected: tool.id == selectedId,
                onToolSelected: onToolSelected,
              ),
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
      ),
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

/// The planner's own row, which always opens as a full page.
PlanningTool _plannerTool(BuildContext context) => PlanningTool(
  id: kDivePlannerToolId,
  icon: Icons.edit_calendar,
  color: Theme.of(context).colorScheme.primary,
  title: context.l10n.planning_card_divePlanner_title,
  subtitle: context.l10n.planning_card_divePlanner_subtitle,
);

/// The keyboard stop for the recent saved plan [planId].
String _planNavKey(String planId) => 'plan:$planId';

void _openPlan(BuildContext context, String planId) =>
    context.push('/planning/dive-planner/$planId');

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
  const _PlannerSection({required this.recentPlans});

  /// The plans to list, the same ones the list's keyboard cursor walks.
  final List<DivePlanSummary> recentPlans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final recent = recentPlans;

    return Column(
      children: [
        KeyboardListItem(
          navigationKey: kDivePlannerToolId,
          child: PlanningTile(
            tool: _plannerTool(context),
            // Never routed into the pane, even in split view: the planner has
            // its own three-pane layout and needs the full window.
            onToolSelected: null,
          ),
        ),
        if (recent.isNotEmpty)
          for (final summary in recent)
            KeyboardListItem(
              navigationKey: _planNavKey(summary.id),
              child: ListTile(
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
                onTap: () => _openPlan(context, summary.id),
              ),
            ),
      ],
    );
  }
}

/// A compact list tile for a planning tool, matching the Insights page style.
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
        onTap: () => select(context, tool, onToolSelected),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  /// Opens [tool] the way tapping its row does, which is also what Enter does
  /// on it from the keyboard.
  ///
  /// A full-page tool navigates even in split view, where every other row
  /// loads the detail pane through [onToolSelected]. This is the general form
  /// of the rule the dive planner has always followed; see
  /// [PlanningToolPresentation].
  static void select(
    BuildContext context,
    PlanningTool tool,
    void Function(String?)? onToolSelected,
  ) {
    if (!tool.isFullPage && onToolSelected != null) {
      onToolSelected(tool.id);
    } else {
      _open(context, tool);
    }
  }

  /// Navigates to [tool] with the verb its presentation requires.
  ///
  /// PUSH by default: tools are sub-pages of the planning hub and must stay
  /// poppable (#647).
  ///
  /// GO for a tool hosting its own split view. Its [MasterDetailScaffold]
  /// selects by calling `go`, which rebuilds the stack from the declarative
  /// route match; arriving on a push leaves the route carrying a generated
  /// page key, so that first selection swaps the key and Flutter animates the
  /// whole page in from the right a second time. `go` on a nested child route
  /// still leaves the hub beneath it, so the tool stays poppable.
  static void _open(BuildContext context, PlanningTool tool) {
    switch (tool.presentation) {
      case PlanningToolPresentation.splitViewPage:
        context.go(tool.route);
      case PlanningToolPresentation.detailPane:
      case PlanningToolPresentation.pushedPage:
        context.push(tool.route);
    }
  }
}
