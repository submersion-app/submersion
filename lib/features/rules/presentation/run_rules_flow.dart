import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/rules/data/services/rule_target_labels.dart';
import 'package:submersion/features/rules/data/services/rule_undo_service.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_preview_sheet.dart';
import 'package:submersion/features/rules/presentation/widgets/rules_page_menus.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(RuleRunRequest);

/// The message an undo shows.
String ruleUndoMessage(AppLocalizations l, RuleUndoResult r) {
  if (r.alreadyUndone) return l.rules_undo_alreadyUndone;
  if (r.nothingYet) return l.rules_undo_nothingYet;
  if (r.skippedEditedTargets > 0) {
    return l.rules_undo_doneSkipped(r.skippedEditedTargets);
  }
  return l.rules_undo_done;
}

/// Undoes [runId] and shows the outcome in a snackbar on [messenger].
Future<void> undoRuleRun(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  AppLocalizations l,
  String runId,
) async {
  try {
    final result = await ref.read(ruleUndoServiceProvider).undo(runId);
    messenger.showSnackBar(SnackBar(content: Text(ruleUndoMessage(l, result))));
  } catch (e, st) {
    _log.error('Failed to undo rule run', error: e, stackTrace: st);
    messenger.showSnackBar(SnackBar(content: Text(l.common_error_tryAgain)));
  }
}

/// Runs the diver's rules for [subject] on demand (#3513): over every
/// eligible item, or [targetIds] when the diver selected some; just
/// [onlyRuleIds] when a rule's own row asked. Previews first, applies only
/// on Apply (recomputing, so a change since the preview counts), then
/// offers Undo. Returns true when something changed.
Future<bool> runRulesOnDemand(
  BuildContext context,
  WidgetRef ref, {
  required RuleSubject subject,
  Set<String>? targetIds,
  List<String>? onlyRuleIds,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final units = UnitFormatter(ref.read(settingsProvider));
  try {
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return false;
    final request = RuleRunRequest(
      diverId: diverId,
      trigger: targetIds == null
          ? RuleRunTrigger.onDemandAll
          : RuleRunTrigger.onDemandSelection,
      targets: {subject: targetIds},
      onlyRuleIds: onlyRuleIds,
    );
    final engine = ref.read(ruleEngineProvider);
    final preview = await engine.preview(request);
    final dives = subject == RuleSubject.dives;
    void noChanges() => messenger.showSnackBar(
      SnackBar(
        content: Text(
          dives ? l.rules_run_noChangesDives : l.rules_run_noChangesSites,
        ),
      ),
    );
    if (!preview.changedAnything) {
      noChanges();
      return false;
    }
    final targets = await RuleTargetLabels().infoFor(subject, {
      for (final c in preview.changes) c.targetId,
    });
    final nameOf = await ref.read(ruleNameOfProvider.future);
    if (!context.mounted) return false;
    final apply = await showRulePreviewSheet(
      context,
      subject: subject,
      preview: preview,
      targets: targets,
      units: units,
      nameOf: nameOf,
    );
    if (!apply) return false;
    final result = await engine.run(request);
    // Apply recomputes; the data may have moved since the preview.
    if (!result.changedAnything) {
      noChanges();
      return false;
    }
    final runId = result.runId!;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          dives
              ? l.rules_run_doneDives(result.changedTargetCount)
              : l.rules_run_doneSites(result.changedTargetCount),
        ),
        action: SnackBarAction(
          label: l.rules_action_undo,
          onPressed: () => undoRuleRun(ref, messenger, l, runId),
        ),
      ),
    );
    return true;
  } catch (e, st) {
    _log.error('Failed to run rules', error: e, stackTrace: st);
    if (context.mounted) showRulesError(context);
    return false;
  }
}

/// Runs the diver's "after creating by hand" rules on a dive or site just
/// saved for the first time (#3513). Silent when nothing changes; otherwise
/// a snackbar names the rules, with Details opening the run (undo lives
/// there). Never blocks the save: a failure is logged and reported.
Future<void> runRulesAfterCreate(
  BuildContext context,
  WidgetRef ref, {
  required RuleSubject subject,
  required List<String> ids,
}) async {
  if (ids.isEmpty) return;
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final router = GoRouter.maybeOf(context);
  // Read before the first await: the saving page may be gone by then.
  final engine = ref.read(ruleEngineProvider);
  final diverIdFuture = ref.read(validatedCurrentDiverIdProvider.future);
  try {
    final diverId = await diverIdFuture;
    if (diverId == null) return;
    final result = await engine.run(
      RuleRunRequest(
        diverId: diverId,
        trigger: RuleRunTrigger.createdByHand,
        targets: {subject: ids.toSet()},
      ),
    );
    if (!result.changedAnything) return;
    final rules = result.changedCountByRule.keys.join(', ');
    final runId = result.runId!;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          subject == RuleSubject.dives
              ? l.rules_create_changedDive(rules)
              : ids.length == 1
              ? l.rules_create_changedSite(rules)
              : l.rules_create_changedSites(rules),
        ),
        action: router == null
            ? null
            : SnackBarAction(
                label: l.rules_create_details,
                onPressed: () => router.push('/rules/history/$runId'),
              ),
      ),
    );
  } catch (e, st) {
    _log.error('Rules could not run after a save', error: e, stackTrace: st);
    messenger?.showSnackBar(SnackBar(content: Text(l.common_error_tryAgain)));
  }
}
