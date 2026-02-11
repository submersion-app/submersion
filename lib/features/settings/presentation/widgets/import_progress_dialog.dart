import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

    final phaseLabel = _getPhaseLabel(context, state.importPhase);
    final progressLabel = state.totalItems > 0
        ? context.l10n.settings_import_progressLabel(
            phaseLabel,
            state.currentItem,
            state.totalItems,
          )
        : phaseLabel;

    return Semantics(
      label: progressLabel,
      liveRegion: true,
      child: AlertDialog(
        title: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.download, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Text(context.l10n.settings_import_dialog_title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase indicator
            Text(
              _getPhaseLabel(context, state.importPhase),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Progress bar
            if (state.totalItems > 0) ...[
              Semantics(
                label: context.l10n.settings_import_progressPercent(
                  (state.progress * 100).toStringAsFixed(0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.settings_import_itemCount(
                  state.currentItem,
                  state.totalItems,
                ),
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
              context.l10n.settings_import_doNotClose,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPhaseLabel(BuildContext context, ImportPhase? phase) {
    switch (phase) {
      case ImportPhase.parsing:
        return context.l10n.settings_import_phase_parsing;
      case ImportPhase.trips:
        return context.l10n.settings_import_phase_trips;
      case ImportPhase.equipment:
        return context.l10n.settings_import_phase_equipment;
      case ImportPhase.equipmentSets:
        return context.l10n.settings_import_phase_equipmentSets;
      case ImportPhase.buddies:
        return context.l10n.settings_import_phase_buddies;
      case ImportPhase.diveCenters:
        return context.l10n.settings_import_phase_diveCenters;
      case ImportPhase.certifications:
        return context.l10n.settings_import_phase_certifications;
      case ImportPhase.diveTypes:
        return context.l10n.settings_import_phase_diveTypes;
      case ImportPhase.tags:
        return context.l10n.settings_import_phase_tags;
      case ImportPhase.sites:
        return context.l10n.settings_import_phase_sites;
      case ImportPhase.dives:
        return context.l10n.settings_import_phase_dives;
      case ImportPhase.complete:
        return context.l10n.settings_import_phase_complete;
      case null:
        return context.l10n.settings_import_phase_preparing;
    }
  }
}
