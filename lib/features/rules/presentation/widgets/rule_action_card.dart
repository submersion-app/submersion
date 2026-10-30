import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One action of a rule in the editor: what it does, with edit and remove.
/// An action naming something deleted is marked so the diver can fix it.
class RuleActionCard extends StatelessWidget {
  const RuleActionCard({
    super.key,
    required this.action,
    required this.units,
    required this.nameOf,
    required this.onEdit,
    required this.onRemove,
  });

  final RuleAction action;
  final UnitFormatter units;
  final RuleNameOf nameOf;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final broken = ruleActionIsBroken(action, nameOf);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          broken ? Icons.warning_amber : Icons.bolt_outlined,
          color: broken ? scheme.tertiary : scheme.primary,
        ),
        title: Text(describeRuleAction(l10n, units, action, nameOf)),
        subtitle: broken ? Text(l10n.rules_problem_brokenAction) : null,
        onTap: onEdit,
        trailing: onRemove == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.common_action_remove,
                onPressed: onRemove,
              ),
      ),
    );
  }
}
