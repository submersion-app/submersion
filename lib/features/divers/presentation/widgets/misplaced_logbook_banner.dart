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
class MisplacedLogbookBanner extends ConsumerStatefulWidget {
  const MisplacedLogbookBanner({super.key});

  @override
  ConsumerState<MisplacedLogbookBanner> createState() =>
      _MisplacedLogbookBannerState();
}

class _MisplacedLogbookBannerState
    extends ConsumerState<MisplacedLogbookBanner> {
  /// True while an action runs. The banner stays up until the dive-count
  /// tick lands, so without this a second Merge could run against the
  /// profile the first one already removed.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    // .value keeps the last answer while a dive-count tick reloads the
    // provider, so the banner does not flicker during a sync or import. That
    // answer may be stale (a Keep both or Switch just landed), so the buttons
    // wait for the reload too.
    final logbook = ref.watch(misplacedLogbookProvider);
    final found = logbook.value;
    if (found == null) return const SizedBox.shrink();
    final busy = _busy || logbook.isLoading;

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
                onPressed: busy ? null : () => _run(() => _switch(found)),
                child: Text(l10n.divers_misplacedLogbook_switchTo),
              ),
              if (found.canMerge)
                FilledButton.tonal(
                  onPressed: busy
                      ? null
                      : () => _run(() => _confirmAndMerge(found)),
                  child: Text(l10n.divers_misplacedLogbook_merge),
                ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => _run(
                        () => ref
                            .read(misplacedLogbookKeptBothProvider.notifier)
                            .keepBoth(found.active.id, found.target.id),
                      ),
                child: Text(l10n.divers_misplacedLogbook_keepBoth),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switch(MisplacedLogbook found) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = context.l10n.settings_profile_switchedTo(found.target.name);
    await ref
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(found.target.id);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmAndMerge(MisplacedLogbook found) async {
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
    if (confirmed != true || !mounted) return;

    // Read before the awaits: the merge removes the active profile, which
    // rebuilds the Dives list and can unmount this banner.
    final repo = ref.read(diverMergeRepositoryProvider);
    final currentDiver = ref.read(currentDiverIdProvider.notifier);
    final diverRepo = ref.read(diverRepositoryProvider);
    final DiverMergeSnapshot snapshot;
    try {
      // [found] was computed before the dialog opened. A sync meanwhile can
      // bring in a second profile with dives, which takes Merge off the table
      // (it may be someone else's logbook), so check the live counts. The
      // banner then rebuilds without Merge.
      final counts = await diverRepo.getDiveCountsByDiver();
      final holders = otherDiveHolderIds(counts, found.active.id);
      if (holders.length != 1 || holders.single != found.target.id) return;
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
            try {
              await repo.undoMerge(snapshot);
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.divers_misplacedLogbook_undoFailed('$e')),
                ),
              );
              return;
            }
            await currentDiver.setCurrentDiver(found.active.id);
          },
        ),
      ),
    );
  }
}
