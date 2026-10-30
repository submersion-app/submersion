import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/rules/presentation/pages/rule_history_page.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_change_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(RuleRunPage);

/// One rule run's change list (#3513), with Undo while it can still be
/// undone. Opened from the history, the import summary and the snackbar
/// after a dive or site is created by hand.
class RuleRunPage extends ConsumerStatefulWidget {
  const RuleRunPage({super.key, required this.runId});

  final String runId;

  @override
  ConsumerState<RuleRunPage> createState() => _RuleRunPageState();
}

class _RuleRunPageState extends ConsumerState<RuleRunPage> {
  RuleChangeGrouping _grouping = RuleChangeGrouping.target;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final detail = ref.watch(ruleRunDetailProvider(widget.runId));
    final units = UnitFormatter(ref.watch(settingsProvider));
    return Scaffold(
      appBar: AppBar(title: Text(l.rules_run_title)),
      body: switch (detail) {
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (value.run != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  ruleRunTriggerLabel(l, value.run!),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RuleChangeGroupingToggle(
                value: _grouping,
                onChanged: (g) => setState(() => _grouping = g),
              ),
            ),
            Expanded(
              child: RuleChangeList(
                changes: value.changes,
                targets: value.targets,
                units: units,
                nameOf: value.nameOf,
                grouping: _grouping,
              ),
            ),
            if (value.run != null && !value.run!.isUndone)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: () => undoRuleRun(
                      ref.read(ruleUndoServiceProvider),
                      ScaffoldMessenger.of(context),
                      l,
                      widget.runId,
                    ),
                    icon: const Icon(Icons.undo),
                    label: Text(l.rules_run_undo),
                  ),
                ),
              ),
          ],
        ),
        AsyncError(:final error, :final stackTrace) => () {
          _log.error(
            'Failed to load run',
            error: error,
            stackTrace: stackTrace,
          );
          return Center(child: Text(l.common_error_tryAgain));
        }(),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
