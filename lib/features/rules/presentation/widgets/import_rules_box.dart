import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/rules/data/services/rule_undo_service.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(ImportRulesBox);

/// The import summary's report of what the diver's rules changed (#3513):
/// counts per rule, the change list, and an undo that keeps the import.
/// Shows nothing when no rule changed anything and nothing failed.
class ImportRulesBox extends ConsumerStatefulWidget {
  const ImportRulesBox({super.key, required this.runs, required this.failed});

  /// One run per diver whose rules changed something.
  final List<RuleRunResult> runs;
  final bool failed;

  @override
  ConsumerState<ImportRulesBox> createState() => _ImportRulesBoxState();
}

class _ImportRulesBoxState extends ConsumerState<ImportRulesBox> {
  bool _undone = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    if (widget.runs.isEmpty && !widget.failed) return const SizedBox.shrink();
    if (widget.runs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          l.rules_import_failed,
          style: TextStyle(color: theme.colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    }
    int changed(RuleSubject s) => {
      for (final r in widget.runs)
        for (final c in r.changes)
          if (c.subject == s) c.targetId,
    }.length;
    final dives = changed(RuleSubject.dives);
    final sites = changed(RuleSubject.sites);
    final perRule = <String, int>{};
    for (final r in widget.runs) {
      for (final e in r.changedCountByRule.entries) {
        perRule[e.key] = (perRule[e.key] ?? 0) + e.value;
      }
    }
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dives > 0)
              Text(
                l.rules_import_changedDives(dives),
                style: theme.textTheme.titleSmall,
              ),
            if (sites > 0)
              Text(
                l.rules_import_changedSites(sites),
                style: theme.textTheme.titleSmall,
              ),
            const SizedBox(height: 4),
            Text(
              [
                for (final e in perRule.entries) '${e.key} ${e.value}',
              ].join(', '),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (widget.failed) ...[
              const SizedBox(height: 4),
              Text(
                l.rules_import_failed,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  // One run opens its change list; a multi-profile import
                  // made one run per profile, all listed in the history.
                  onPressed: () => context.push(
                    widget.runs.length == 1
                        ? '/rules/history/${widget.runs.single.runId}'
                        : '/rules/history',
                  ),
                  child: Text(l.rules_import_seeChanges),
                ),
                if (!_undone)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _undo,
                    icon: const Icon(Icons.undo),
                    label: Text(l.rules_import_undo),
                  ),
              ],
            ),
            if (!_undone) ...[
              const SizedBox(height: 4),
              Text(l.rules_import_undoNote, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _undo() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final service = ref.read(ruleUndoServiceProvider);
      final results = [
        for (final r in widget.runs) await service.undo(r.runId!),
      ];
      final combined = RuleUndoResult.combine(results);
      if (mounted) {
        setState(() {
          _busy = false;
          _undone = !combined.nothingYet && !combined.alreadyUndone;
        });
      }
      messenger.showSnackBar(
        SnackBar(content: Text(ruleUndoMessage(l, combined))),
      );
    } catch (e, st) {
      _log.error('Failed to undo import rules', error: e, stackTrace: st);
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l.common_error_tryAgain)));
    }
  }
}
