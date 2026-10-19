import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/rules/data/services/rule_target_labels.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_change_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shows what an on-demand run would change and asks to apply it. Returns
/// true when the diver presses Apply.
Future<bool> showRulePreviewSheet(
  BuildContext context, {
  required RuleSubject subject,
  required RuleRunResult preview,
  required Map<String, RuleTargetInfo> targets,
  required UnitFormatter units,
  required RuleNameOf nameOf,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PreviewSheet(
        subject: subject,
        preview: preview,
        targets: targets,
        units: units,
        nameOf: nameOf,
      ),
    ) ??
    false;

class _PreviewSheet extends StatefulWidget {
  const _PreviewSheet({
    required this.subject,
    required this.preview,
    required this.targets,
    required this.units,
    required this.nameOf,
  });

  final RuleSubject subject;
  final RuleRunResult preview;
  final Map<String, RuleTargetInfo> targets;
  final UnitFormatter units;
  final RuleNameOf nameOf;

  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> {
  RuleChangeGrouping _grouping = RuleChangeGrouping.target;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = widget.preview;
    final dives = widget.subject == RuleSubject.dives;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final notes = ruleRunNotes(
      l,
      outOfScope: p.outOfScopeCount,
      skippedRules: p.skippedRuleNames,
      skippedActions: p.skippedActionRuleNames,
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                dives
                    ? l.rules_preview_titleDives(p.targetCount)
                    : l.rules_preview_titleSites(p.targetCount),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                dives
                    ? l.rules_preview_willChangeDives(p.changedTargetCount)
                    : l.rules_preview_willChangeSites(p.changedTargetCount),
                style: TextStyle(color: muted),
              ),
            ),
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(n, style: TextStyle(color: muted)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RuleChangeGroupingToggle(
                value: _grouping,
                onChanged: (g) => setState(() => _grouping = g),
              ),
            ),
            Flexible(
              child: RuleChangeList(
                changes: p.changes,
                targets: widget.targets,
                units: widget.units,
                nameOf: widget.nameOf,
                grouping: _grouping,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l.common_action_cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('rule_preview_apply'),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      dives
                          ? l.rules_preview_applyDives(p.changedTargetCount)
                          : l.rules_preview_applySites(p.changedTargetCount),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
