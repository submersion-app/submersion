import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/tracks/application/tracks_match_controller.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Reports a Match press: the dives positioned and the underwater tracks
/// linked. Positioned dives get the "Review site matches" action, which
/// hands their ids to the site review.
///
/// When the diver was offered tracks to link (#4851), declined, and nothing
/// was positioned, nothing is shown: the dialog they just answered said it
/// all. Choosing Link always reports how many were linked, even none.
void showTracksMatchOutcome({
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required GoRouter router,
  required TracksMatchOutcome outcome,
}) {
  final positioned = outcome.positionedDiveIds;
  final linked = outcome.linkedTrackCount;
  // What did happen is said even when a part failed, so a diver knows
  // which tracks are already linked before trying again.
  final done = [
    if (positioned.isNotEmpty) l10n.gpsLogger_matchResult(positioned.length),
    if (linked > 0 || outcome.linkConfirmed)
      l10n.navTrack_match_linkedResult(linked),
  ];
  final String message;
  if (outcome.failed) {
    message = [...done, l10n.common_error_tryAgain].join(' · ');
  } else if (done.isEmpty) {
    // An earlier press's message would read as this one's.
    if (outcome.linkProposals.isNotEmpty) {
      messenger.clearSnackBars();
      return;
    }
    message = l10n.gpsLogger_matchResultNone;
  } else {
    message = done.join(' · ');
  }
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        // #406: an action defaults to persist: true; force auto-dismiss.
        persist: false,
        showCloseIcon: true,
        action: positioned.isEmpty
            ? null
            : SnackBarAction(
                label: l10n.gpsLogger_reviewSites,
                onPressed: () =>
                    router.push('/dives/match-sites', extra: positioned),
              ),
      ),
    );
}
