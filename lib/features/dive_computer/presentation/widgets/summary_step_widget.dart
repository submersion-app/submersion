import 'package:flutter/material.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/dive_comparison_card.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
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

    final hasPendingMatches = downloadState.pendingConsolidations.isNotEmpty;
    final diveCount = hasPendingMatches
        ? downloadState.downloadedDives.length
        : downloadState.totalImported;
    final headerVerb = hasPendingMatches ? 'downloaded' : 'imported';

    final computerName =
        computer?.displayName ?? context.l10n.diveComputer_summary_diveComputer;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact header: icon + title + computer name
          Semantics(
            label: context.l10n.diveComputer_summary_semanticLabel(
              diveCount,
              computerName,
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$diveCount ${diveCount == 1 ? 'dive' : 'dives'} '
                        '$headerVerb from $computerName',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (computer?.serialNumber != null)
                        Text(
                          'S/N: ${computer!.serialNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Consolidation section (if duplicates found)
          if (downloadState.pendingConsolidations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildConsolidationSection(
                  context,
                  ref,
                  downloadState,
                  theme,
                  colorScheme,
                ),
              ),
            ),
          ],

          // Only show imported dives and actions after all matches are resolved
          if (downloadState.pendingConsolidations.isEmpty) ...[
            // Imported dives list
            if (downloadState.totalImported > 0) ...[
              const SizedBox(height: 12),
              _buildDownloadedDivesList(
                context,
                downloadState,
                theme,
                colorScheme,
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons side by side
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDone,
                    child: Text(context.l10n.diveComputer_summary_done),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onViewDives,
                    icon: const Icon(Icons.list),
                    label: Text(context.l10n.diveComputer_summary_viewDives),
                  ),
                ),
              ],
            ),
          ],
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
          (candidate) => DiveComparisonCard(
            incoming: IncomingDiveData.fromDownloadedDive(
              candidate.dive,
              computer: computer,
            ),
            existingDiveId: candidate.matchedDiveId,
            matchScore: candidate.matchScore,
            incomingLabel: 'Downloaded',
            onSkip: () => notifier.skipConsolidation(candidate),
            onImportAsNew: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await notifier.importCandidateAsNew(candidate);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Imported as separate dive.')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Import failed: $e')),
                );
              }
            },
            onConsolidate: () async {
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

  Widget _buildDownloadedDivesList(
    BuildContext context,
    DownloadState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final dives = state.importResult?.importedDives ?? [];

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
                Text('Imported Dives', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${state.totalImported}',
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
}
