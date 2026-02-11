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
  /// Tracks the user's override selection. Null means no override chosen.
  SourceApp? _selectedOverride;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(universalImportNotifierProvider);
    final theme = Theme.of(context);
    final detection = state.detectionResult;

    if (detection == null) return const SizedBox.shrink();

    return Padding(
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

          // Detection result card
          Semantics(
            label: detection.isHighConfidence
                ? context.l10n.universalImport_semantics_sourceDetected(
                    detection.description,
                  )
                : context.l10n.universalImport_semantics_sourceUncertain(
                    detection.description,
                  ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            detection.isHighConfidence
                                ? Icons.check_circle
                                : Icons.help_outline,
                            color: detection.isHighConfidence
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

          const SizedBox(height: 24),

          // Confirm button
          if (detection.isFormatSupported)
            FilledButton(
              onPressed: () => ref
                  .read(universalImportNotifierProvider.notifier)
                  .confirmSource(overrideApp: _selectedOverride),
              child: Text(context.l10n.universalImport_action_continue),
            ),

          const SizedBox(height: 12),

          // Override section (collapsible)
          Expanded(
            child: _OverrideSection(
              selectedOverride: _selectedOverride,
              onChanged: (app) => setState(() => _selectedOverride = app),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible section for overriding the detected source app.
class _OverrideSection extends StatelessWidget {
  final SourceApp? selectedOverride;
  final ValueChanged<SourceApp?> onChanged;

  const _OverrideSection({
    required this.selectedOverride,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apps = SourceApp.values.where((a) => a != SourceApp.generic).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.universalImport_label_selectCorrectSource,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RadioGroup<SourceApp?>(
            groupValue: selectedOverride,
            onChanged: onChanged,
            child: ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return ListTile(
                  dense: true,
                  title: Text(app.displayName),
                  leading: Radio<SourceApp?>(value: app),
                  onTap: () => onChanged(app),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
