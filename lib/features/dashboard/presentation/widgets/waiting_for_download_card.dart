import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/download_target_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/unfilled_dive_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The drafts out of the water and waiting for a download, newest first: a
/// draft still open is a dive in progress, not one waiting.
List<Dive> draftsWaitingForDownload(List<Dive> drafts) => [
  for (final dive in drafts)
    if (dive.exitTime != null) dive,
];

/// Home card for drafts waiting for a dive computer download (issue #637):
/// how many, the newest few, and "Download now". Hidden when none wait.
class WaitingForDownloadCard extends ConsumerWidget {
  const WaitingForDownloadCard({super.key});

  /// How many drafts the card lists by name.
  static const shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = draftsWaitingForDownload(
      ref.watch(draftDivesProvider).value ?? const [],
    );
    if (waiting.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final target = ref.watch(downloadTargetComputerProvider).value;

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.downloading,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.dashboard_waitingForDownload_title(waiting.length),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final dive in waiting.take(shown))
                  ListTile(
                    key: ValueKey('waiting-draft-${dive.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      unfilledDiveIcon(UnfilledDiveState.awaitingDownload),
                    ),
                    title: Text(dive.site?.name ?? l10n.diveLog_draft_title),
                    subtitle: Text(
                      units.formatDateTime(
                        dive.entryTime ?? dive.dateTime,
                        l10n: l10n,
                      ),
                    ),
                    onTap: () => context.push('/dives/${dive.id}'),
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.download),
                    label: Text(l10n.dashboard_waitingForDownload_download),
                    onPressed: () => context.push(downloadRouteFor(target)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
