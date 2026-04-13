import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Pill indicating a row is a suspected duplicate that still needs an
/// explicit user decision before the import can proceed.
///
/// Used by the review step's duplicate card widgets when their `isPending`
/// flag is true.
class NeedsDecisionPill extends StatelessWidget {
  const NeedsDecisionPill({super.key, required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.universalImport_semantics_needsDecision,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.tertiary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.tertiary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.universalImport_pending_needsDecision,
              style: TextStyle(
                color: colorScheme.tertiary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
