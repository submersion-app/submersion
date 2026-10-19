import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/features/rules/presentation/widgets/rules_page_menus.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(RuleHistoryPage);

/// What started [run], as the history shows it.
String ruleRunTriggerLabel(AppLocalizations l, RuleRun run) =>
    switch (run.trigger) {
      RuleRunTrigger.imported =>
        run.sourceLabel == null || run.sourceLabel!.isEmpty
            ? l.rules_history_triggerImported
            : l.rules_history_triggerImportedFrom(run.sourceLabel!),
      RuleRunTrigger.createdByHand => l.rules_history_triggerCreatedByHand,
      RuleRunTrigger.onDemandAll => l.rules_history_triggerOnDemandAll,
      RuleRunTrigger.onDemandSelection =>
        l.rules_history_triggerOnDemandSelection,
    };

/// Settings > Manage > Rules > History (#3513): every run that changed
/// something, newest first, each undoable until it is undone or deleted.
class RuleHistoryPage extends ConsumerWidget {
  const RuleHistoryPage({super.key, this.runIds});

  /// Just these runs, whichever profile each belongs to (a multi-profile
  /// import's See changes); null for the active diver's whole history.
  final List<String>? runIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ids = runIds;
    final runs = ids == null
        ? ref.watch(ruleRunsProvider)
        : ref.watch(ruleRunsByIdsProvider(ids.join(',')));
    // Clearing is for the whole history, not a few runs shown from an
    // import.
    final hasRuns = ids == null && (runs.value?.isNotEmpty ?? false);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.rules_history_title),
        actions: [
          if (hasRuns)
            PopupMenuButton<int>(
              key: const ValueKey('rules_history_menu'),
              onSelected: (_) => _confirmClear(context, ref),
              itemBuilder: (_) => [
                PopupMenuItem(value: 0, child: Text(l.rules_history_clear)),
              ],
            ),
        ],
      ),
      body: runs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          _log.error('Failed to load rule history', error: e, stackTrace: st);
          return Center(child: Text(l.common_error_tryAgain));
        },
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l.rules_history_empty,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _RunTile(run: list[i]),
              ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.rules_history_clearDialog_title),
        content: Text(l.rules_history_clearDialog_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.rules_history_clear),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId != null) {
        await ref.read(ruleRunRepositoryProvider).deleteAllRuns(diverId);
      }
    } catch (e, st) {
      _log.error('Failed to clear rule history', error: e, stackTrace: st);
      if (context.mounted) showRulesError(context);
    }
  }
}

class _RunTile extends ConsumerWidget {
  const _RunTile({required this.run});

  final RuleRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final details = [
      units.formatDateTime(run.ranAt, l10n: l),
      l.rules_history_changed(run.changedCount, run.ruleNames.join(', ')),
      if (run.deviceLabel != null && run.deviceLabel!.isNotEmpty)
        l.rules_history_device(run.deviceLabel!),
    ];
    return ListTile(
      title: Text(ruleRunTriggerLabel(l, run)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in details) Text(d),
          if (run.isUndone)
            Text(
              l.rules_history_undone(
                units.formatDateTime(run.undoneAt, l10n: l),
              ),
              style: TextStyle(color: muted, fontStyle: FontStyle.italic),
            ),
        ],
      ),
      isThreeLine: true,
      onTap: () => context.push('/rules/history/${run.id}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!run.isUndone)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: l.rules_history_undoTooltip,
              onPressed: () => undoRuleRun(
                ref.read(ruleUndoServiceProvider),
                ScaffoldMessenger.of(context),
                l,
                run.id,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l.rules_history_deleteTooltip,
            onPressed: () async {
              try {
                await ref.read(ruleRunRepositoryProvider).deleteRun(run.id);
              } catch (e, st) {
                _log.error('Failed to delete run', error: e, stackTrace: st);
                if (context.mounted) showRulesError(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
