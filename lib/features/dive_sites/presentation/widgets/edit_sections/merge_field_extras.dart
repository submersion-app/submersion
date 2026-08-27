import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Per-field merge affordance: which source site the current value came
/// from, and how to cycle to the next candidate.
class MergeFieldExtras {
  const MergeFieldExtras({required this.sourceLabel, required this.onCycle});

  final String sourceLabel;
  final VoidCallback onCycle;
}

/// Small tonal cycle button shown next to a field in merge mode.
class MergeCycleButton extends StatelessWidget {
  const MergeCycleButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: context.l10n.diveSites_edit_merge_fieldSourceCycleTooltip,
      icon: const Icon(Icons.sync_alt, size: 18),
      iconSize: 18,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(6),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Caption + cycle button row for fields that are not text rows
/// (coordinates, difficulty, rating).
class MergeSourceRow extends StatelessWidget {
  const MergeSourceRow({
    super.key,
    required this.sourceLabel,
    required this.onCycle,
  });

  final String sourceLabel;
  final VoidCallback onCycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sourceLabel,
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          MergeCycleButton(onPressed: onCycle),
        ],
      ),
    );
  }
}
