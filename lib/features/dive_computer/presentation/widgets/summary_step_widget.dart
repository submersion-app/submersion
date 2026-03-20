import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Widget for the summary step of the discovery wizard.
class SummaryStepWidget extends ConsumerWidget {
  final DiveComputer? computer;
  final VoidCallback onDone;
  final VoidCallback onViewDives;

  const SummaryStepWidget({
    super.key,
    required this.computer,
    required this.onDone,
    required this.onViewDives,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final diveCount = downloadState.downloadedDives.length;
    final importResult = downloadState.importResult;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Success icon
          ExcludeSemantics(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer,
              ),
              child: Icon(Icons.check, size: 56, color: colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            context.l10n.diveComputer_summary_title,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),

          // Summary
          Semantics(
            label: context.l10n.diveComputer_summary_semanticLabel(
              diveCount,
              computer?.displayName ??
                  context.l10n.diveComputer_summary_diveComputer,
            ),
            child: Text(
              context.l10n.diveComputer_summary_divesDownloaded(diveCount),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Computer card
          if (computer != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.watch,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            computer!.displayName,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            computer!.fullName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Import stats
          if (importResult != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (importResult.imported > 0)
                      _buildStatRow(
                        context,
                        Icons.add_circle_outline,
                        context.l10n.diveComputer_summary_imported,
                        '${importResult.imported}',
                        colorScheme.primary,
                      ),
                    if (importResult.skipped > 0)
                      _buildStatRow(
                        context,
                        Icons.skip_next,
                        context.l10n.diveComputer_summary_skippedDuplicates,
                        '${importResult.skipped}',
                        colorScheme.onSurfaceVariant,
                      ),
                    if (importResult.updated > 0)
                      _buildStatRow(
                        context,
                        Icons.update,
                        context.l10n.diveComputer_summary_updated,
                        '${importResult.updated}',
                        colorScheme.secondary,
                      ),
                    if (downloadState.pendingConsolidations.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildConsolidationSection(
                        context,
                        ref,
                        downloadState,
                        theme,
                        colorScheme,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // Downloaded dives list
          if (downloadState.downloadedDives.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDownloadedDivesList(
              context,
              downloadState,
              theme,
              colorScheme,
            ),
          ],

          const SizedBox(height: 32),

          // Actions
          FilledButton.icon(
            onPressed: onViewDives,
            icon: const Icon(Icons.list),
            label: Text(context.l10n.diveComputer_summary_viewDives),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onDone,
            child: Text(context.l10n.diveComputer_summary_done),
          ),
        ],
      ),
    );
  }

  Widget _buildConsolidationSection(
    BuildContext context,
    WidgetRef ref,
    DownloadState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final notifier = ref.read(downloadNotifierProvider.notifier);
    final candidates = state.pendingConsolidations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.merge, color: colorScheme.tertiary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Potential Matches (${candidates.length})',
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'These dives match existing dives and can be added as '
          'additional computer data.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...candidates.map(
          (candidate) => _buildCandidateCard(
            context,
            candidate,
            notifier,
            theme,
            colorScheme,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              for (final candidate in List.of(candidates)) {
                try {
                  await notifier.consolidateDive(candidate);
                } catch (_) {}
              }
              messenger.showSnackBar(
                const SnackBar(content: Text('All matches consolidated.')),
              );
            },
            icon: const Icon(Icons.merge),
            label: const Text('Consolidate All'),
          ),
        ),
      ],
    );
  }

  Widget _buildCandidateCard(
    BuildContext context,
    DuplicateCandidate candidate,
    DownloadNotifier notifier,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final matchPercent = (candidate.matchScore * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar with match confidence
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
            child: Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  size: 16,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$matchPercent% match',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Side-by-side comparison in bordered columns
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Existing dive (left)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                    child: Consumer(
                      builder: (context, ref, _) => _buildExistingDiveColumn(
                        context,
                        ref,
                        candidate.matchedDiveId,
                        theme,
                        colorScheme,
                      ),
                    ),
                  ),
                ),
                // Imported dive (right)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: _buildImportedDiveColumn(
                      candidate.dive,
                      theme,
                      colorScheme,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action buttons bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => notifier.skipConsolidation(candidate),
                  child: const Text('Skip'),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await notifier.importCandidateAsNew(candidate);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Imported as separate dive.'),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Import failed: $e')),
                      );
                    }
                  },
                  child: const Text('Import as New'),
                ),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await notifier.consolidateDive(candidate);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Dive consolidated successfully.'),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Consolidation failed: $e')),
                      );
                    }
                  },
                  child: const Text('Consolidate'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportedDiveColumn(
    DownloadedDive dive,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final date = dive.startTime;
    final dateStr =
        '${date.month}/${date.day}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    final computerLabel = computer != null ? computer!.fullName : 'Downloaded';
    final serial = computer?.serialNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Computer',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(computerLabel, style: theme.textTheme.bodySmall),
        if (serial != null)
          Text(
            'S/N: $serial',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 6),
        Text(dateStr, style: theme.textTheme.bodySmall),
        Text(
          '${dive.maxDepth.toStringAsFixed(1)}m / '
          '${dive.durationSeconds ~/ 60}min',
          style: theme.textTheme.bodySmall,
        ),
        if (dive.minTemperature != null)
          Text(
            '${dive.minTemperature!.toStringAsFixed(0)}C',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildExistingDiveColumn(
    BuildContext context,
    WidgetRef ref,
    String diveId,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final existingAsync = ref.watch(diveProvider(diveId));

    return existingAsync.when(
      data: (dive) {
        if (dive == null) {
          return Text('Existing dive', style: theme.textTheme.bodySmall);
        }
        final date = dive.entryTime ?? dive.effectiveEntryTime;
        final dateStr =
            '${date.month}/${date.day}/${date.year} '
            '${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')}';
        final diveNum = dive.diveNumber;
        final durationMin = dive.duration?.inMinutes;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Existing Dive${diveNum != null ? ' #$diveNum' : ''}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            if (dive.diveComputerModel != null)
              Text(dive.diveComputerModel!, style: theme.textTheme.bodySmall),
            if (dive.diveComputerSerial != null)
              Text(
                'S/N: ${dive.diveComputerSerial}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 6),
            Text(dateStr, style: theme.textTheme.bodySmall),
            Text(
              '${dive.maxDepth?.toStringAsFixed(1) ?? '?'}m / '
              '${durationMin != null ? '${durationMin}min' : '?'}',
              style: theme.textTheme.bodySmall,
            ),
            if (dive.waterTemp != null)
              Text(
                '${dive.waterTemp!.toStringAsFixed(0)}C',
                style: theme.textTheme.bodySmall,
              ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => Text('Existing dive', style: theme.textTheme.bodySmall),
    );
  }

  Widget _buildDownloadedDivesList(
    BuildContext context,
    DownloadState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final dives = state.downloadedDives;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.scuba_diving, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('Downloaded Dives', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${dives.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: dives.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final dive = dives[index];
                  final date = dive.startTime;
                  final dateStr =
                      '${date.month}/${date.day}/${date.year} '
                      '${date.hour.toString().padLeft(2, '0')}:'
                      '${date.minute.toString().padLeft(2, '0')}';
                  final details = <String>[
                    '${dive.maxDepth.toStringAsFixed(1)}m',
                    '${dive.durationSeconds ~/ 60}min',
                  ];
                  if (dive.avgDepth != null) {
                    details.add('avg ${dive.avgDepth!.toStringAsFixed(1)}m');
                  }
                  if (dive.minTemperature != null) {
                    details.add('${dive.minTemperature!.toStringAsFixed(0)}C');
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (dive.diveNumber != null) ...[
                              Text(
                                '#${dive.diveNumber}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                dateStr,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          children: [
                            for (final detail in details)
                              Text(detail, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(width: 12),
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
