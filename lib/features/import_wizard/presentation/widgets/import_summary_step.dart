import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/data_quality/presentation/providers/quality_inbox_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_file_outcome.dart';
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
      attachedPhotoCount: result.attachedPhotoCount,
      unmatchedPhotoCount: result.unmatchedPhotoCount,
      importedDiveIds: result.importedDiveIds,
      fileOutcomes: result.fileOutcomes,
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
  final int attachedPhotoCount;
  final int unmatchedPhotoCount;
  final List<String> importedDiveIds;
  final List<ImportFileOutcome> fileOutcomes;
  final VoidCallback onDone;
  final VoidCallback onViewDives;

  const _SuccessView({
    required this.importedCounts,
    required this.consolidatedCount,
    this.updatedCount = 0,
    required this.skippedCount,
    this.attachedPhotoCount = 0,
    this.unmatchedPhotoCount = 0,
    this.importedDiveIds = const [],
    this.fileOutcomes = const [],
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
            if (attachedPhotoCount > 0)
              _CountRow(
                icon: Icons.photo_library_outlined,
                label: l10n.universalImport_label_photosAttached,
                count: attachedPhotoCount,
                key: const Key('import_summary_photos_row'),
              ),
            if (unmatchedPhotoCount > 0)
              _CountRow(
                icon: Icons.hide_image_outlined,
                label: l10n.universalImport_label_photosUnmatched,
                count: unmatchedPhotoCount,
                key: const Key('import_summary_unmatched_photos_row'),
              ),
            if (skippedCount > 0)
              _CountRow(
                icon: Icons.skip_next,
                label: 'Skipped',
                count: skippedCount,
                key: const Key('import_summary_skipped_row'),
              ),
            if (importedDiveIds.isNotEmpty)
              Consumer(
                builder: (context, ref, _) {
                  final count =
                      ref
                          .watch(
                            importedDivesOpenFindingsCountProvider(
                              importedDivesFindingsKey(importedDiveIds),
                            ),
                          )
                          .value ??
                      0;
                  if (count == 0) return const SizedBox.shrink();
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.rule),
                    title: Text(l10n.dataQuality_summary_flagged(count)),
                    trailing: TextButton(
                      onPressed: () => context.push(
                        '/dives/quality?dive=${importedDiveIds.join(',')}',
                      ),
                      child: Text(l10n.dataQuality_summary_review),
                    ),
                  );
                },
              ),
            if (fileOutcomes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.universalImport_summary_filesTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final outcome in fileOutcomes)
                _FileOutcomeRow(outcome: outcome),
            ],
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
            Consumer(
              builder: (context, ref, _) {
                if (importedDiveIds.isEmpty) return const SizedBox.shrink();
                final eligible = ref.watch(
                  eligibleImportedDivesProvider(
                    ImportedDiveIds(importedDiveIds),
                  ),
                );
                return eligible.maybeWhen(
                  data: (ids) => ids.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: FilledButton.icon(
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: Text(
                              context.l10n.importSummary_matchSitesButton(
                                ids.length,
                              ),
                            ),
                            onPressed: () =>
                                context.push('/dives/match-sites', extra: ids),
                          ),
                        ),
                  orElse: () => const SizedBox.shrink(),
                );
              },
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
// Per-file outcome row (bulk imports)
// ---------------------------------------------------------------------------

class _FileOutcomeRow extends StatelessWidget {
  final ImportFileOutcome outcome;

  const _FileOutcomeRow({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final icon = switch (outcome.status) {
      ImportFileOutcomeStatus.imported => Icons.check_circle_outline,
      ImportFileOutcomeStatus.parseFailed => Icons.error_outline,
      ImportFileOutcomeStatus.needsIndividualImport => Icons.block,
      ImportFileOutcomeStatus.unsupported => Icons.help_outline,
    };
    final label = switch (outcome.status) {
      ImportFileOutcomeStatus.imported =>
        l10n.universalImport_summary_fileImported(outcome.importedDives),
      ImportFileOutcomeStatus.parseFailed =>
        l10n.universalImport_summary_fileParseFailed,
      ImportFileOutcomeStatus.needsIndividualImport =>
        l10n.universalImport_summary_fileNeedsIndividualImport,
      ImportFileOutcomeStatus.unsupported =>
        l10n.universalImport_summary_fileUnsupported,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              outcome.fileName,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
