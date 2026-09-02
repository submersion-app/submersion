import 'package:flutter/material.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the Gas Calculators detail pane shows before a calculator is picked.
///
/// Deliberately no calculator shortcuts. The list is permanently visible in
/// the master pane a few hundred pixels to the left, so repeating it here
/// would duplicate rather than add. This mirrors the reasoning in
/// `PlanningSummaryWidget`, which had a genuine second thing to show and so
/// shows it; this pane does not, and says so plainly instead of inventing
/// filler.
class GasCalculatorsSummaryWidget extends StatelessWidget {
  const GasCalculatorsSummaryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.l10n.gasCalculators_title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.gasCalculators_summary_prompt,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          color: colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: colorScheme.onSurfaceVariant,
                ).excludeFromSemantics(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.planning_info_disclaimer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
