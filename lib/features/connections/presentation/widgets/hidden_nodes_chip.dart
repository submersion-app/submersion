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
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return ActionChip(
      key: const ValueKey('connections-hidden-chip'),
      avatar: const Icon(Icons.more_horiz, size: 18),
      label: Text(context.l10n.connections_hiddenNodes(count)),
      onPressed: onShowAll,
    );
  }
}
