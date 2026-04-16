import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The summary step shown after the import completes.
///
/// Shows a success view with per-entity import counts, consolidated and
/// skipped summaries, and "Done" / "View Dives" action buttons.
///
/// On error, shows an error icon and message with a "Done" button.
///
/// While the import is still running, shows a loading indicator.
class ImportSummaryStep extends ConsumerWidget {
  /// Called when the user taps the "Done" button.
  final VoidCallback onDone;

  /// Called when the user taps the "View Dives" button.
  final VoidCallback onViewDives;

  const ImportSummaryStep({
    super.key,
    required this.onDone,
    required this.onViewDives,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardNotifierProvider);
    final result = state.importResult;

    if (result == null) {
      final error = state.error;
      if (error != null) {
        return _ErrorView(errorMessage: error, onDone: onDone);
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (result.errorMessage != null) {
      return _ErrorView(errorMessage: result.errorMessage!, onDone: onDone);
    }

    return _SuccessView(
      importedCounts: result.importedCounts,
      consolidatedCount: result.consolidatedCount,
      updatedCount: result.updatedCount,
      skippedCount: result.skippedCount,
      onDone: onDone,
      onViewDives: onViewDives,
    );
  }
}

// ---------------------------------------------------------------------------
// Success view
// ---------------------------------------------------------------------------

class _SuccessView extends StatelessWidget {
  final Map<ImportEntityType, int> importedCounts;
  final int consolidatedCount;
  final int updatedCount;
  final int skippedCount;
  final VoidCallback onDone;
  final VoidCallback onViewDives;

  const _SuccessView({
    required this.importedCounts,
    required this.consolidatedCount,
    this.updatedCount = 0,
    required this.skippedCount,
    required this.onDone,
    required this.onViewDives,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalImported = importedCounts.values.fold<int>(
      0,
      (sum, v) => sum + v,
    );
    final hasActivity =
        totalImported > 0 || consolidatedCount > 0 || updatedCount > 0;

    final String title;
    final IconData icon;
    final Color iconColor;
    final Color iconBg;
    final l10n = context.l10n;
    if (hasActivity) {
      if (totalImported > 0) {
        title = l10n.universalImport_title_successImported;
      } else if (updatedCount > 0) {
        title = l10n.universalImport_title_successUpdated;
      } else {
        title = l10n.universalImport_title_successConsolidated;
      }
      icon = Icons.check;
      iconColor = theme.colorScheme.onPrimaryContainer;
      iconBg = theme.colorScheme.primaryContainer;
    } else {
      title = l10n.universalImport_title_noDivesImported;
      icon = Icons.info_outline;
      iconColor = theme.colorScheme.onSurfaceVariant;
      iconBg = theme.colorScheme.surfaceContainerHighest;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              key: const Key('import_summary_success_title'),
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (!hasActivity && skippedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.universalImport_label_allDivesSkipped,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            for (final entry in importedCounts.entries)
              if (entry.value > 0)
                _CountRow(
                  icon: _iconForType(entry.key),
                  label: _labelForType(entry.key),
                  count: entry.value,
                ),
            if (updatedCount > 0)
              _CountRow(
                icon: Icons.sync,
                label: l10n.universalImport_label_replacedSourceData,
                count: updatedCount,
                key: const Key('import_summary_updated_row'),
              ),
            if (consolidatedCount > 0)
              _CountRow(
                icon: Icons.merge,
                label: l10n.universalImport_label_consolidated,
                count: consolidatedCount,
                key: const Key('import_summary_consolidated_row'),
              ),
            if (skippedCount > 0)
              _CountRow(
                icon: Icons.skip_next,
                label: 'Skipped',
                count: skippedCount,
                key: const Key('import_summary_skipped_row'),
              ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(onPressed: onDone, child: const Text('Done')),
                if (hasActivity) ...[
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: onViewDives,
                    child: const Text('View Dives'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(ImportEntityType type) {
    switch (type) {
      case ImportEntityType.dives:
        return Icons.scuba_diving;
      case ImportEntityType.sites:
        return Icons.location_on;
      case ImportEntityType.buddies:
        return Icons.people;
      case ImportEntityType.equipment:
        return Icons.build;
      case ImportEntityType.trips:
        return Icons.luggage;
      case ImportEntityType.certifications:
        return Icons.verified;
      case ImportEntityType.diveCenters:
        return Icons.store;
      case ImportEntityType.tags:
        return Icons.label;
      case ImportEntityType.diveTypes:
        return Icons.category;
      case ImportEntityType.equipmentSets:
        return Icons.inventory;
      case ImportEntityType.courses:
        return Icons.school;
    }
  }

  String _labelForType(ImportEntityType type) {
    switch (type) {
      case ImportEntityType.dives:
        return 'Dives';
      case ImportEntityType.sites:
        return 'Sites';
      case ImportEntityType.buddies:
        return 'Buddies';
      case ImportEntityType.equipment:
        return 'Equipment';
      case ImportEntityType.trips:
        return 'Trips';
      case ImportEntityType.certifications:
        return 'Certifications';
      case ImportEntityType.diveCenters:
        return 'Dive Centers';
      case ImportEntityType.tags:
        return 'Tags';
      case ImportEntityType.diveTypes:
        return 'Dive Types';
      case ImportEntityType.equipmentSets:
        return 'Equipment Sets';
      case ImportEntityType.courses:
        return 'Courses';
    }
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onDone;

  const _ErrorView({required this.errorMessage, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 20),
            Text(
              errorMessage,
              key: const Key('import_summary_error_message'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Count row
// ---------------------------------------------------------------------------

class _CountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _CountRow({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            '$count',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
