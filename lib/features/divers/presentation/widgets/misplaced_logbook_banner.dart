import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/divers/domain/misplaced_logbook.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/misplaced_logbook_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Banner at the top of the Dives list when this device's active profile is
/// empty and another profile holds the logbook (issue #3549). Sits where the
/// diver is looking when their dives seem lost, and stays until they switch,
/// merge, or keep both.
class MisplacedLogbookBanner extends ConsumerWidget {
  const MisplacedLogbookBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = ref.watch(misplacedLogbookProvider).asData?.value;
    if (found == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_search, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.divers_misplacedLogbook_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.divers_misplacedLogbook_body(
              found.target.name,
              found.targetDiveCount,
              found.active.name,
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => _switch(context, ref, found),
                child: Text(l10n.divers_misplacedLogbook_switchTo),
              ),
              if (found.canMerge)
                FilledButton.tonal(
                  onPressed: () => _confirmAndMerge(context, ref, found),
                  child: Text(l10n.divers_misplacedLogbook_merge),
                ),
              TextButton(
                onPressed: () => ref
                    .read(misplacedLogbookKeptBothProvider.notifier)
                    .keepBoth(found.active.id, found.target.id),
                child: Text(l10n.divers_misplacedLogbook_keepBoth),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _switch(
    BuildContext context,
    WidgetRef ref,
    MisplacedLogbook found,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = context.l10n.settings_profile_switchedTo(found.target.name);
    await ref
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(found.target.id);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmAndMerge(
    BuildContext context,
    WidgetRef ref,
    MisplacedLogbook found,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.divers_misplacedLogbook_confirmTitle),
        content: Text(
          l10n.divers_misplacedLogbook_confirmBody(
            found.active.name,
            found.target.name,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.divers_misplacedLogbook_confirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.divers_misplacedLogbook_confirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Read before the awaits: the merge removes the active profile, which
    // rebuilds the Dives list and can unmount this banner.
    final repo = ref.read(diverMergeRepositoryProvider);
    final currentDiver = ref.read(currentDiverIdProvider.notifier);
    final DiverMergeSnapshot snapshot;
    try {
      snapshot = await repo.mergeDivers(
        keeperId: found.target.id,
        duplicateId: found.active.id,
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.divers_misplacedLogbook_mergeFailed('$e'))),
      );
      return;
    }
    // Point the device at the profile kept. Left alone, the active-diver
    // notifier would fall back to the default profile, which may not be it.
    await currentDiver.setCurrentDiver(found.target.id);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          l10n.divers_misplacedLogbook_mergedSnack(found.target.name),
        ),
        action: SnackBarAction(
          label: l10n.divers_misplacedLogbook_undo,
          onPressed: () async {
            await repo.undoMerge(snapshot);
            await currentDiver.setCurrentDiver(found.active.id);
          },
        ),
      ),
    );
  }
}
