import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/tracks/application/tracks_match_controller.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Reports a Match press. Positioned dives get the "Review site matches"
/// action, which hands their ids to the site review.
void showTracksMatchOutcome({
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required GoRouter router,
  required TracksMatchOutcome outcome,
}) {
  final positioned = outcome.positionedDiveIds;
  final message = outcome.failed
      ? l10n.common_error_tryAgain
      : positioned.isEmpty
      ? l10n.gpsLogger_matchResultNone
      : l10n.gpsLogger_matchResult(positioned.length);
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
