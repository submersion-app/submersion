import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/link_dive_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Links plan [planId] to dive [diveId] (issue #4003), confirming first when
/// that moves the plan off another dive or takes the dive from another plan.
/// Returns whether the link was made.
///
/// The planner is told, because it holds its plan in memory and a later save
/// would otherwise write the old link back. The providers are read before the
/// first await so [ref] is not used across an async gap.
Future<bool> linkPlanWithConfirm(
  BuildContext context,
  WidgetRef ref, {
  required String planId,
  required String diveId,
}) async {
  final repository = ref.read(divePlanRepositoryProvider);
  final planner = ref.read(divePlanNotifierProvider.notifier);
  final plan = await repository.getPlan(planId);
  if (plan == null) return false;
  if (plan.linkedDiveId == diveId) return true;
  final holder = await repository.getPlanByLinkedDiveId(diveId);
  final displaced = holder != null && holder.id != planId ? holder : null;
  final moving = plan.linkedDiveId != null && plan.linkedDiveId != diveId;
  if (moving || displaced != null) {
    if (!context.mounted) return false;
    final l10n = context.l10n;
    final confirmed = await _confirm(
      context,
      title: displaced == null
          ? l10n.diveLab_link_moveTitle
          : l10n.diveLab_link_replaceTitle,
      body: [
        if (moving) l10n.diveLab_link_moveBody,
        if (displaced != null) l10n.diveLab_link_replaceBody(displaced.name),
      ].join('\n\n'),
      action: l10n.diveLab_link_confirm,
    );
    if (!confirmed) return false;
  }
  final result = await repository.linkPlanToDive(planId, diveId);
  planner.adoptLink(planId, diveId);
  for (final id in result.displacedPlanIds) {
    planner.adoptLink(id, null);
  }
  return true;
}

/// Asks before a step that moves a plan's link off the dive it names. [action]
/// labels the button that goes ahead.
Future<bool> confirmLinkMove(BuildContext context, {required String action}) {
  final l10n = context.l10n;
  return _confirm(
    context,
    title: l10n.diveLab_link_moveTitle,
    body: l10n.diveLab_link_moveBody,
    action: action,
  );
}

/// Clears plan [planId]'s link once the diver confirms. Returns whether it did.
Future<bool> unlinkPlanWithConfirm(
  BuildContext context,
  WidgetRef ref, {
  required String planId,
}) async {
  final repository = ref.read(divePlanRepositoryProvider);
  final planner = ref.read(divePlanNotifierProvider.notifier);
  final l10n = context.l10n;
  final confirmed = await _confirm(
    context,
    title: l10n.diveLab_link_unlinkTitle,
    body: l10n.diveLab_link_unlinkBody,
    action: l10n.diveLab_link_unlinkConfirm,
  );
  if (!confirmed) return false;
  await repository.unlinkPlan(planId);
  planner.adoptLink(planId, null);
  return true;
}

/// Picks a logged dive for plan [planId] and links it. The plan's own day,
/// when it has one, leads the list. Returns whether a link was made.
Future<bool> pickDiveAndLink(
  BuildContext context,
  WidgetRef ref, {
  required String planId,
}) async {
  final plan = await ref.read(divePlanRepositoryProvider).getPlan(planId);
  if (plan == null || !context.mounted) return false;
  final diveId = await showLinkDiveSheet(
    context,
    planDay: plan.startDateTime,
    currentDiveId: plan.linkedDiveId,
  );
  if (diveId == null || !context.mounted) return false;
  return linkPlanWithConfirm(context, ref, planId: planId, diveId: diveId);
}

/// What a saved plan shows about its linked dive; null when it has none.
String? planLinkBadge(
  AppLocalizations l10n,
  DivePlanSummary summary,
  UnitFormatter units,
) {
  if (summary.linkedDiveId == null) return null;
  if (summary.linkedDiveIsPlanned) return l10n.diveLab_compare_waiting;
  final number = summary.linkedDiveNumber;
  if (number != null) return l10n.plannerCanvas_link_badge(number);
  final date = summary.linkedDiveDate;
  if (date != null) {
    return l10n.plannerCanvas_link_badgeDate(units.formatDate(date));
  }
  return null;
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
