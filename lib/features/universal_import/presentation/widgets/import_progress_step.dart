import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// Step 4: Import progress indicator.
class ImportProgressStep extends ConsumerWidget {
  const ImportProgressStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final theme = Theme.of(context);
    final progress = state.importTotal > 0
        ? state.importCurrent / state.importTotal
        : null;

    final progressLabel = state.importTotal > 0
        ? context.l10n.universalImport_label_importingProgress(
            state.importCurrent,
            state.importTotal,
          )
        : context.l10n.universalImport_label_importing;
    final phaseLabel = state.importPhase.isNotEmpty
        ? ', ${state.importPhase}'
        : '';

    return Semantics(
      label: '$progressLabel$phaseLabel',
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ExcludeSemantics(
              child: SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.universalImport_label_importingEllipsis,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (state.importPhase.isNotEmpty)
              Text(
                state.importPhase,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
            if (progress != null)
              Semantics(
                label: context.l10n.universalImport_semantics_importProgress(
                  (progress * 100).toStringAsFixed(0),
                ),
                child: LinearProgressIndicator(value: progress),
              )
            else
              const LinearProgressIndicator(),
            if (state.importTotal > 0) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.universalImport_label_xOfY(
                  state.importCurrent,
                  state.importTotal,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 24),
              Semantics(
                label: context.l10n.universalImport_semantics_importError(
                  state.error!,
                ),
                liveRegion: true,
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
