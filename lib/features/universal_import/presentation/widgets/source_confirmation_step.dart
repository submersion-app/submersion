import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// Step 1: Show detection result and let user confirm or override.
class SourceConfirmationStep extends ConsumerStatefulWidget {
  const SourceConfirmationStep({super.key});

  @override
  ConsumerState<SourceConfirmationStep> createState() =>
      _SourceConfirmationStepState();
}

class _SourceConfirmationStepState
    extends ConsumerState<SourceConfirmationStep> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(universalImportNotifierProvider);
    final theme = Theme.of(context);
    final detection = state.detectionResult;
    final selectedOverride = state.pendingSourceOverride;

    if (detection == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File info
          if (state.fileName != null) ...[
            Text(
              state.fileName!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Detection result card — tappable to clear override
          Semantics(
            label: detection.isHighConfidence
                ? context.l10n.universalImport_semantics_sourceDetected(
                    detection.description,
                  )
                : context.l10n.universalImport_semantics_sourceUncertain(
                    detection.description,
                  ),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: selectedOverride != null
                    ? () => ref
                          .read(universalImportNotifierProvider.notifier)
                          .setPendingSourceOverride(null)
                    : null,
                child: Opacity(
                  opacity: selectedOverride != null ? 0.5 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                selectedOverride != null
                                    ? Icons.radio_button_unchecked
                                    : detection.isHighConfidence
                                    ? Icons.check_circle
                                    : Icons.help_outline,
                                color: selectedOverride != null
                                    ? theme.colorScheme.onSurfaceVariant
                                    : detection.isHighConfidence
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.tertiary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                detection.description,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                        if (!detection.isFormatSupported) ...[
                          const SizedBox(height: 12),
                          Text(
                            detection.sourceApp?.exportInstructions ??
                                context
                                    .l10n
                                    .universalImport_error_unsupportedFormat,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        if (detection.warnings.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (final warning in detection.warnings)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                warning,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Override section (collapsed by default)
          _OverrideSection(
            selectedOverride: SourceOverrideOption.findMatch(
              selectedOverride,
              state.pendingFormatOverride,
            ),
            onChanged: (option) {
              final notifier = ref.read(
                universalImportNotifierProvider.notifier,
              );
              if (option != null) {
                notifier.setPendingSourceOverride(
                  option.sourceApp,
                  format: option.format,
                );
              } else {
                notifier.setPendingSourceOverride(null);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Collapsible section for overriding the detected source app and format.
class _OverrideSection extends StatelessWidget {
  final SourceOverrideOption? selectedOverride;
  final ValueChanged<SourceOverrideOption?> onChanged;

  const _OverrideSection({
    required this.selectedOverride,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          context.l10n.universalImport_label_selectCorrectSource,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        dense: true,
        visualDensity: VisualDensity.compact,
        children: [
          RadioGroup<SourceOverrideOption?>(
            groupValue: selectedOverride,
            onChanged: onChanged,
            child: Column(
              children: [
                for (final option in SourceOverrideOption.supported)
                  ListTile(
                    dense: true,
                    title: Text(option.displayName),
                    leading: Radio<SourceOverrideOption?>(value: option),
                    onTap: () => onChanged(option),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
