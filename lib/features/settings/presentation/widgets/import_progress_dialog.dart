import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/export_providers.dart';

/// Dialog shown during UDDF/CSV import with progress tracking
class ImportProgressDialog extends ConsumerWidget {
  const ImportProgressDialog({super.key});

  /// Shows the import progress dialog and returns when import completes
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ImportProgressDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exportNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Auto-dismiss when complete or error
    if (state.status == ExportStatus.success ||
        state.status == ExportStatus.error ||
        state.status == ExportStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download, color: colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Importing Data'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase indicator
          Text(
            _getPhaseLabel(state.importPhase),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar
          if (state.totalItems > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.currentItem} of ${state.totalItems}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const LinearProgressIndicator(),
          ],

          const SizedBox(height: 16),

          // Status message
          if (state.message != null)
            Text(
              state.message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

          const SizedBox(height: 8),
          Text(
            'Please do not close the app',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _getPhaseLabel(ImportPhase? phase) {
    switch (phase) {
      case ImportPhase.parsing:
        return 'Parsing file...';
      case ImportPhase.trips:
        return 'Importing trips...';
      case ImportPhase.equipment:
        return 'Importing equipment...';
      case ImportPhase.equipmentSets:
        return 'Importing equipment sets...';
      case ImportPhase.buddies:
        return 'Importing buddies...';
      case ImportPhase.diveCenters:
        return 'Importing dive centers...';
      case ImportPhase.certifications:
        return 'Importing certifications...';
      case ImportPhase.diveTypes:
        return 'Importing dive types...';
      case ImportPhase.tags:
        return 'Importing tags...';
      case ImportPhase.sites:
        return 'Importing dive sites...';
      case ImportPhase.dives:
        return 'Importing dives...';
      case ImportPhase.complete:
        return 'Finalizing...';
      case null:
        return 'Preparing...';
    }
  }
}
