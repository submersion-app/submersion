import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/species_id/data/services/run_media_resolvers.dart';
import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/auto_apply_rules.dart';
import 'package:submersion/features/species_id/presentation/providers/dive_species_run_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_review_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether the dive's Marine life card has the panel to show (issue
/// #4727): something to review (every device), or a model to look at the
/// dive's photos and videos with.
bool diveFindSpeciesWanted(WidgetRef ref, Dive dive) {
  final toReview =
      ref.watch(speciesReviewCountProvider(DiveReviewScope(dive.id))).value ??
      0;
  if (toReview > 0) return true;
  return _canFind(ref, dive);
}

bool _canFind(WidgetRef ref, Dive dive) {
  if (!marineLifeIdEnabled) return false;
  if (ref.watch(installedSpeciesPackProvider).value == null) return false;
  return _hasPhotosOrVideos(ref, dive);
}

/// Whether the dive's Marine life card offers the model download (issue
/// #4773): the offer is wanted, and the dive has photos or videos it could
/// look at.
bool diveDownloadPromptWanted(WidgetRef ref, Dive dive) =>
    ref.watch(speciesDownloadPromptProvider) && _hasPhotosOrVideos(ref, dive);

bool _hasPhotosOrVideos(WidgetRef ref, Dive dive) {
  final media = ref.watch(mediaForDiveProvider(dive.id)).value ?? const [];
  return media.any(
    (m) => m.mediaType == MediaType.photo || m.mediaType == MediaType.video,
  );
}

/// Find species in photos, its progress, and the way to Species to review,
/// at the foot of the dive's Marine life card (issue #4727).
class DiveFindSpeciesPanel extends ConsumerStatefulWidget {
  const DiveFindSpeciesPanel({super.key, required this.dive});

  final Dive dive;

  @override
  ConsumerState<DiveFindSpeciesPanel> createState() =>
      _DiveFindSpeciesPanelState();
}

class _DiveFindSpeciesPanelState extends ConsumerState<DiveFindSpeciesPanel> {
  Dive get dive => widget.dive;

  /// Counting or asking before a run: a second tap waits on the first
  /// rather than opening a second prompt.
  var _asking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scope = DiveReviewScope(dive.id);
    final toReview = ref.watch(speciesReviewCountProvider(scope)).value ?? 0;
    final run = ref.watch(diveSpeciesRunProvider)[dive.id];
    ref.listen(diveSpeciesRunProvider.select((runs) => runs[dive.id]?.phase), (
      previous,
      next,
    ) {
      if (previous != DiveRunPhase.finished && next == DiveRunPhase.finished) {
        _showSummary(context, ref);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canFind(ref, dive)) _runLine(context, ref, l10n, run),
        if (run?.phase == DiveRunPhase.finished)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _summary(l10n, run!.summary, toReview),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (toReview > 0)
          ListTile(
            key: const ValueKey('dive_species_review_link'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.speciesReview_count(toReview)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/species/review?dive=${dive.id}'),
          ),
      ],
    );
  }

  Widget _runLine(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    DiveSpeciesRunState? run,
  ) {
    final runs = ref.read(diveSpeciesRunProvider.notifier);
    if (run != null && run.isActive) {
      final paused = run.phase == DiveRunPhase.paused;
      final hot = paused && run.pauseReason == DiveRunPause.tooHot;
      final text = run.phase == DiveRunPhase.waiting
          ? l10n.speciesReview_waiting
          : hot
          ? l10n.speciesReview_pausedHot
          : l10n.speciesReview_finding(run.done, run.total);
      return Row(
        children: [
          if (!hot)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  // How far it has got; spinning only while waiting.
                  value: run.total == 0 ? null : run.done / run.total,
                ),
              ),
            ),
          Expanded(child: Text(text)),
          // Resume for a background pause too: the app's return normally
          // ends it, but a diver is never left without a way on.
          if (paused)
            TextButton(
              key: const ValueKey('dive_species_resume'),
              onPressed: () => runs.resume(dive.id),
              child: Text(l10n.speciesReview_resume),
            ),
          TextButton(
            key: const ValueKey('dive_species_cancel'),
            onPressed: () => runs.cancel(dive.id),
            child: Text(l10n.common_action_cancel),
          ),
        ],
      );
    }
    // Nothing new to look at: a run would do nothing, unless something is
    // left to review and auto-apply would tag what is confident, which needs
    // it switched on and a pack that can be confident.
    final toReview =
        ref.watch(speciesReviewCountProvider(DiveReviewScope(dive.id))).value ??
        0;
    // Watched whatever the count, so Find reads the set it was built from.
    final upToDate =
        ref.watch(diveSpeciesCheckedProvider(dive.id)).value == true;
    final naming = ref
        .watch(installedSpeciesPackProvider)
        .value
        ?.manifest
        .naming;
    final runCanApply =
        ref.watch(autoApplyProvider) && naming != null && packCanApply(naming);
    final checked = upToDate && (toReview == 0 || !runCanApply);
    // A dive a run would do nothing on can still be checked again, from the
    // start (issue #4825).
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        key: ValueKey(
          checked ? 'dive_species_check_again' : 'dive_species_find',
        ),
        icon: const Icon(Icons.travel_explore_outlined),
        label: Text(
          checked ? l10n.speciesReview_checkAgain : l10n.speciesReview_find,
        ),
        onPressed: () => _start(context, ref, fresh: checked),
      ),
    );
  }

  Future<void> _start(
    BuildContext context,
    WidgetRef ref, {
    required bool fresh,
  }) async {
    if (_asking) return;
    _asking = true;
    try {
      if (fresh && !await _confirmCheckAgain(context)) return;
      if (!context.mounted) return;
      await _countAndStart(context, ref, fresh: fresh);
    } finally {
      _asking = false;
    }
  }

  /// Checking again brings dismissed suggestions back: the diver agrees
  /// first.
  Future<bool> _confirmCheckAgain(BuildContext context) async {
    final l10n = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.speciesReview_checkAgainTitle),
        content: Text(l10n.speciesReview_checkAgainBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: const ValueKey('dive_species_check_again_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.speciesReview_checkAgain),
          ),
        ],
      ),
    );
    return go ?? false;
  }

  Future<void> _countAndStart(
    BuildContext context,
    WidgetRef ref, {
    required bool fresh,
  }) async {
    final media = [
      for (final m in await ref.read(mediaForDiveProvider(dive.id).future))
        if (m.mediaType == MediaType.photo || m.mediaType == MediaType.video) m,
    ];
    // Only what the run will open: media up to date is not read again,
    // except by a fresh run, which opens it all.
    final missing = await notOnDeviceCount(
      media,
      checked: fresh
          ? const {}
          : await ref.read(diveMediaUpToDateProvider(dive.id).future),
      libraryOriginalHere: ref.read(libraryOriginalHereProvider),
    );
    if (missing > 0) {
      if (!context.mounted) return;
      final l10n = context.l10n;
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.speciesReview_downloadBody(missing)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.common_action_cancel),
            ),
            FilledButton(
              key: const ValueKey('dive_species_download'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.speciesReview_downloadAndFind),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    // Not awaited: the run outlives the tap; its own start dedups.
    unawaited(
      ref.read(diveSpeciesRunProvider.notifier).start(dive.id, fresh: fresh),
    );
  }

  void _showSummary(BuildContext context, WidgetRef ref) {
    final run = ref.read(diveSpeciesRunProvider)[dive.id];
    if (run == null) return;
    final toReview =
        ref.read(speciesReviewCountProvider(DiveReviewScope(dive.id))).value ??
        0;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(_summary(context.l10n, run.summary, toReview))),
    );
  }

  static String _summary(
    AppLocalizations l10n,
    DiveRunSummary summary,
    int toReview,
  ) {
    final text = l10n.speciesReview_summary(
      l10n.speciesReview_photos(summary.photos),
      l10n.speciesReview_videos(summary.videos),
      l10n.speciesReview_speciesTagged(summary.speciesTagged),
      toReview,
    );
    return summary.unreadable == 0
        ? text
        : '$text ${l10n.speciesReview_summaryUnreadable(summary.unreadable)}';
  }
}
