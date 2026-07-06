import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Present the saved-plans picker as a modal bottom sheet.
Future<void> showSavedPlansSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const SavedPlansSheet(),
  );
}

/// Lists saved plans (newest first) with open, duplicate, and delete.
class SavedPlansSheet extends ConsumerWidget {
  const SavedPlansSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(divePlanSummariesProvider);
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));

    // Render stale data during a reload rather than flashing a spinner.
    final plans = summaries.valueOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.plannerCanvas_saved_title,
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
                  context.l10n.plannerCanvas_saved_empty,
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
                      _PlanTile(summary: plans[i], units: units),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile({required this.summary, required this.units});

  final DivePlanSummary summary;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(summary.updatedAt);
    final subtitleParts = <String>[
      date,
      if (summary.maxDepth != null) units.formatDepth(summary.maxDepth!),
      if (summary.runtimeSeconds != null)
        '${(summary.runtimeSeconds! / 60).ceil()}′',
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(summary.name),
      subtitle: Text(subtitleParts.join(' · ')),
      onTap: () {
        context.pop();
        context.go('/planning/dive-planner/${summary.id}');
      },
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          final repository = ref.read(divePlanRepositoryProvider);
          if (value == 'duplicate') {
            await repository.duplicatePlan(summary.id);
          } else if (value == 'delete') {
            final confirmed = await _confirmDelete(context);
            if (confirmed) await repository.deletePlan(summary.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'duplicate',
            child: Text(context.l10n.plannerCanvas_saved_duplicate),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.plannerCanvas_saved_deleteConfirmTitle),
        content: Text(
          context.l10n.plannerCanvas_saved_deleteConfirmBody(summary.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
