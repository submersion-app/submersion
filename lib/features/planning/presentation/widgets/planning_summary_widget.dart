import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the Planning detail pane shows before a tool is picked.
///
/// The entity lists put a summary here rather than leaving the pane blank, and
/// Planning has something genuinely useful to fill it with: the full list of
/// saved plans, which the hub beside it caps at three.
///
/// Deliberately no tool shortcuts. In split view the tool list is permanently
/// visible in the master pane a few hundred pixels to the left, so repeating
/// it here would duplicate rather than add.
class PlanningSummaryWidget extends ConsumerWidget {
  const PlanningSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plansAsync = ref.watch(divePlanSummariesProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.l10n.planning_appBar_title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.planning_summary_prompt,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.planning_summary_savedPlans.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        _savedPlans(context, plansAsync, units),
      ],
    );
  }

  /// "No saved plans yet" is a claim about the data, so it may only be made
  /// once the query has actually answered. Rendering it off
  /// `valueOrNull ?? const []` asserted it during the first load, telling a
  /// diver with a full plan library that they had none.
  ///
  /// Retained values win over a reload, so a refresh keeps showing the plans
  /// instead of flickering back through the placeholder. Same shape as the
  /// no-fly readout, for the same reason.
  Widget _savedPlans(
    BuildContext context,
    AsyncValue<List<DivePlanSummary>> plansAsync,
    UnitFormatter units,
  ) {
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

    return Card(
      child: Column(
        children: [
          for (final plan in plans.take(8))
            ListTile(
              leading: const Icon(Icons.route),
              title: Text(plan.name),
              subtitle: Text(
                [
                  if (plan.maxDepth != null) units.formatDepth(plan.maxDepth!),
                  if (plan.runtimeSeconds != null)
                    '${(plan.runtimeSeconds! / 60).ceil()}′',
                  plan.mode.name.toUpperCase(),
                ].join(' · '),
              ),
              onTap: () => context.push('/planning/dive-planner/${plan.id}'),
            ),
        ],
      ),
    );
  }
}
