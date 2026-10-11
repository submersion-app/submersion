import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "N more not shown"; tapping offers to raise the budget.
class HiddenNodesChip extends StatelessWidget {
  const HiddenNodesChip({
    super.key,
    required this.count,
    required this.onShowAll,
  });

  final int count;

  /// Null once the budget is at its ceiling: the count stays, the action
  /// goes.
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = Text(context.l10n.connections_hiddenNodes(count));
    final action = onShowAll;
    if (action == null) {
      return Chip(key: const ValueKey('connections-hidden-chip'), label: label);
    }
    return ActionChip(
      key: const ValueKey('connections-hidden-chip'),
      avatar: const Icon(Icons.more_horiz, size: 18),
      label: label,
      onPressed: action,
    );
  }
}

/// Asks before raising the node budget past what lays out quickly; true
/// when the diver chose to show all [total] entities.
Future<bool> confirmShowAll(BuildContext context, int total) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.connections_showAll_confirmTitle),
      content: Text(l10n.connections_showAll_confirmBody(total)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.connections_showAll),
        ),
      ],
    ),
  );
  return ok == true;
}
