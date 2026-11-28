import 'package:flutter/material.dart';

import 'package:submersion/features/species_id/domain/entities/species_batch.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Whether [previous] to [next] is a run over many dives ending, which the
/// app tells wherever the diver is (issue #5127).
bool speciesBatchEnded(
  SpeciesBatchRunState? previous,
  SpeciesBatchRunState? next,
) =>
    (previous?.isActive ?? false) &&
    next != null &&
    !next.isActive &&
    next.diveCount > 0;

/// The line the end of a run over many dives is told with: what it looked
/// at and tagged, and what it left out. [toReview] is what Species to
/// review holds now.
String speciesBatchEndText(
  AppLocalizations l10n,
  SpeciesBatchRunState state, {
  required int toReview,
}) {
  final summary = state.summary;
  return [
    if (state.phase == SpeciesBatchPhase.cancelled) l10n.speciesBatch_stopped,
    l10n.speciesReview_summary(
      l10n.speciesReview_photos(summary.photos),
      l10n.speciesReview_videos(summary.videos),
      l10n.speciesReview_speciesTagged(summary.speciesTagged),
      toReview,
    ),
    if (summary.unreadable > 0)
      l10n.speciesReview_summaryUnreadable(summary.unreadable),
    if (summary.notOnDevice > 0)
      l10n.speciesBatch_summaryNotOnDevice(summary.notOnDevice),
  ].join(' ');
}

/// The snack bar for the end of a run over many dives, with Review when
/// there is something to review.
SnackBar speciesBatchEndSnackBar(
  AppLocalizations l10n,
  SpeciesBatchRunState state, {
  required int toReview,
  required VoidCallback onReview,
}) => SnackBar(
  content: Text(speciesBatchEndText(l10n, state, toReview: toReview)),
  duration: const Duration(seconds: 8),
  action: toReview > 0
      ? SnackBarAction(label: l10n.speciesBatch_review, onPressed: onReview)
      : null,
);
