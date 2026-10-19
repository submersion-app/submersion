import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(RuleRowMenu);

/// The plain "try again" snackbar every rules write failure shows; the
/// detail goes to the log.
void showRulesError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.l10n.common_error_tryAgain),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}

enum _RowAction { runOnAll, duplicate, delete }

/// A rule row's menu: run it on everything, duplicate or delete it.
class RuleRowMenu extends ConsumerWidget {
  const RuleRowMenu({super.key, required this.rule});

  final Rule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<_RowAction>(
      tooltip: l10n.rules_row_menuTooltip,
      onSelected: (action) => switch (action) {
        _RowAction.runOnAll => runRulesOnDemand(
          context,
          ref,
          subject: rule.subject,
          onlyRuleIds: [rule.id],
        ),
        _RowAction.duplicate => _duplicate(context, ref),
        _RowAction.delete => _delete(context, ref),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _RowAction.runOnAll,
          enabled: rule.isRunnable,
          child: Text(
            rule.subject == RuleSubject.dives
                ? l10n.rules_row_runOnAllDives
                : l10n.rules_row_runOnAllSites,
          ),
        ),
        PopupMenuItem(
          value: _RowAction.duplicate,
          child: Text(l10n.rules_row_duplicate),
        ),
        PopupMenuItem(
          value: _RowAction.delete,
          child: Text(l10n.rules_row_delete),
        ),
      ],
    );
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(ruleRepositoryProvider)
          .duplicate(rule.id, nameSuffix: context.l10n.rules_copySuffix);
    } catch (e, st) {
      _log.error('Failed to duplicate rule', error: e, stackTrace: st);
      if (context.mounted) showRulesError(context);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    // Read before the dialog: the row can be rebuilt away while it is up,
    // and a confirmed delete must still land and be reported.
    final repository = ref.read(ruleRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.rules_deleteDialog_title),
        content: Text(l10n.rules_deleteDialog_content(rule.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repository.delete(rule.id);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.rules_snackbar_deleted(rule.name))),
      );
    } catch (e, st) {
      _log.error('Failed to delete rule', error: e, stackTrace: st);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.common_error_tryAgain),
          backgroundColor: errorColor,
        ),
      );
    }
  }
}

/// The Rules page's "Run rules" menu: every enabled dive rule over all
/// dives, or every enabled site rule over all sites.
class RunRulesMenuButton extends ConsumerWidget {
  const RunRulesMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<RuleSubject>(
      key: const ValueKey('rules_run_all'),
      icon: const Icon(Icons.play_arrow_outlined),
      tooltip: l10n.rules_action_runAll,
      onSelected: (subject) => runRulesOnDemand(context, ref, subject: subject),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: RuleSubject.dives,
          child: Text(l10n.rules_action_runAllDives),
        ),
        PopupMenuItem(
          value: RuleSubject.sites,
          child: Text(l10n.rules_action_runAllSites),
        ),
      ],
    );
  }
}
