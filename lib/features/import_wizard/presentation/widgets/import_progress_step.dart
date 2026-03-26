import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';

/// The importing progress step of the import wizard.
///
/// Displays the current import phase, a progress fraction (e.g. "8 of 12"),
/// a circular progress indicator, and a linear progress bar.
class ImportProgressStep extends ConsumerWidget {
  const ImportProgressStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardNotifierProvider);
    final theme = Theme.of(context);

    final phase = state.importPhase;
    final current = state.importCurrent;
    final total = state.importTotal;

    final fraction = (total > 0) ? current / total : null;
    final phaseText = phase != null ? 'Importing $phase...' : 'Importing...';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    key: const Key('import_progress_circular'),
                    value: fraction,
                    strokeWidth: 6,
                  ),
                ),
                if (fraction != null)
                  Text(
                    '${(fraction * 100).round()}%',
                    style: theme.textTheme.labelLarge,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              phaseText,
              key: const Key('import_progress_phase_text'),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (total > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$current of $total',
                key: const Key('import_progress_count_text'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            LinearProgressIndicator(
              key: const Key('import_progress_linear'),
              value: fraction,
            ),
          ],
        ),
      ),
    );
  }
}
