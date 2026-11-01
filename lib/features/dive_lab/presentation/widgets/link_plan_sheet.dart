import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/plan_link_actions.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Picks a saved plan for dive [diveId] and links it. Returns whether it did.
Future<bool> pickPlanAndLink(
  BuildContext context,
  WidgetRef ref, {
  required String diveId,
}) async {
  final planId = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => LinkPlanSheet(diveId: diveId),
  );
  if (planId == null || !context.mounted) return false;
  return linkPlanWithConfirm(context, ref, planId: planId, diveId: diveId);
}

/// Saved plans that are free, newest first, then plans linked to other dives,
/// greyed with the dive they belong to. Those stay tappable: moving a link is
/// allowed, after confirming.
class LinkPlanSheet extends ConsumerWidget {
  const LinkPlanSheet({super.key, required this.diveId});

  final String diveId;

  bool _elsewhere(DivePlanSummary plan) =>
      plan.linkedDiveId != null && plan.linkedDiveId != diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(divePlanSummariesProvider);
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final l10n = context.l10n;

    // Render stale data during a reload rather than flashing a spinner.
    final loaded = summaries.valueOrNull;
    final plans = loaded == null
        ? null
        : [...loaded.where((p) => !_elsewhere(p)), ...loaded.where(_elsewhere)];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.diveLab_compare_linkPlan,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (plans == null && summaries.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (plans == null || plans.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.plannerCanvas_saved_empty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  itemBuilder: (context, i) =>
                      _planTile(context, plans[i], units),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _planTile(
    BuildContext context,
    DivePlanSummary plan,
    UnitFormatter units,
  ) {
    final elsewhere = _elsewhere(plan);
    final outline = Theme.of(context).colorScheme.outline;
    final subtitleParts = <String>[
      units.formatDate(plan.updatedAt),
      if (plan.maxDepth != null) units.formatDepth(plan.maxDepth!),
      if (plan.runtimeSeconds != null) '${(plan.runtimeSeconds! / 60).ceil()}′',
      if (elsewhere) ?planLinkBadge(context.l10n, plan, units),
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        plan.name,
        style: elsewhere ? TextStyle(color: outline) : null,
      ),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: plan.linkedDiveId == diveId ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(plan.id),
    );
  }
}
