import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/utils/plan_mode_grouping.dart';
import 'package:submersion/features/planner/domain/utils/plan_summary_sort.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';

/// The saved-plans list: every plan, grouped by [PlanMode] and sorted per
/// [divePlanSortProvider].
///
/// Shared by the desktop detail pane (`PlanningSummaryWidget`'s "Saved
/// plans" section) and the phone-only full page reached from the hub's own
/// "Saved plans" row (issue #3551) — the row exists only because a phone has
/// no detail pane to show this content in; both surfaces are this same
/// widget, so they behave identically and share one sort state rather than
/// drifting apart.
class SavedPlansList extends ConsumerWidget {
  const SavedPlansList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(divePlanSummariesProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));

    // "No saved plans yet" is a claim about the data, so it may only be made
    // once the query has actually answered; retained values win over a
    // reload, so a refresh keeps showing the plans instead of flickering
    // back through the placeholder.
    if (!plansAsync.hasValue) {
      return Card(
        child: ListTile(
          leading: Icon(
            plansAsync.hasError ? Icons.error_outline : Icons.hourglass_empty,
          ),
          title: Text(
            plansAsync.hasError
                ? context.l10n.common_label_error
                : context.l10n.common_label_loading,
          ),
        ),
      );
    }

    final plans = plansAsync.requireValue;
    if (plans.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.route),
          title: Text(context.l10n.planning_summary_noPlans),
          subtitle: Text(context.l10n.planning_card_divePlanner_subtitle),
          onTap: () => context.push('/planning/dive-planner'),
        ),
      );
    }

    final sort = ref.watch(divePlanSortProvider);
    final groups = groupPlansByMode(sortPlanSummaries(plans, sort));

    return Card(
      child: Column(
        children: [
          for (final group in groups) ...[
            _ModeHeader(group.mode),
            for (final plan in group.plans)
              ListTile(
                leading: const Icon(Icons.route),
                title: Text(plan.name),
                subtitle: Text(
                  [
                    if (plan.maxDepth != null)
                      units.formatDepth(plan.maxDepth!),
                    if (plan.runtimeSeconds != null)
                      '${(plan.runtimeSeconds! / 60).ceil()}′',
                  ].join(' · '),
                ),
                onTap: () => context.push('/planning/dive-planner/${plan.id}'),
              ),
          ],
        ],
      ),
    );
  }
}

/// Opens the sort sheet [SavedPlansList] reads, from either of its callers'
/// own sort buttons (the desktop pane's label row and the phone page's app
/// bar action).
void openSavedPlansSortSheet(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final sort = ref.read(divePlanSortProvider);
  showSortBottomSheet<DivePlanSortField>(
    context: context,
    title: l10n.planning_summary_savedPlans,
    currentField: sort.field,
    currentDirection: sort.direction,
    fields: DivePlanSortField.values,
    getFieldDisplayName: (field) => field.localizedName(l10n),
    getFieldIcon: (field) => field.icon,
    onSortChanged: (field, direction) {
      ref.read(divePlanSortProvider.notifier).state = SortState(
        field: field,
        direction: direction,
      );
    },
  );
}

/// Group header matching the hub's own section-label style.
class _ModeHeader extends StatelessWidget {
  const _ModeHeader(this.mode);

  final PlanMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        mode.name.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
