import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// Step 0: File selection with drag-and-drop area and file picker button.
class FileSelectionStep extends ConsumerWidget {
  const FileSelectionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open),
              label: Text(state.isLoading ? 'Detecting...' : 'Select File'),
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(universalImportNotifierProvider.notifier)
                        .pickFile(),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: state.error!),
          ],
          const Spacer(),
          Icon(
            Icons.upload_file,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('Import Data', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Select a dive log file to import. Supported formats include '
            'CSV, UDDF, Subsurface XML, and Garmin FIT.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
