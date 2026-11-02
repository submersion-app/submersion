import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What has been corrected on a track, on its detail page. Opens the same
/// alignment page as the AppBar's tune icon (#4023): the status it summarizes
/// is what that page sets.
class NavTrackCorrectionCard extends StatelessWidget {
  const NavTrackCorrectionCard({super.key, required this.route});

  final NavTrack route;

  /// To 0.1%, with no decimal on a whole percentage.
  String _scalePercent() {
    final percent = (route.scaleFactor * 1000).round() / 10;
    return formatFixedForDisplay(percent, percent % 1 == 0 ? 0 : 1);
  }

  String _status(AppLocalizations l10n) => switch (route.endMode) {
    NavTrackEndMode.none => l10n.navTrack_detail_correctionStatus_none,
    NavTrackEndMode.sameAsStart =>
      l10n.navTrack_detail_correctionStatus_sameAsStart,
    NavTrackEndMode.point => l10n.navTrack_detail_correctionStatus_point,
    NavTrackEndMode.gpsFix => l10n.navTrack_detail_correctionStatus_gpsFix,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('nav-track-correction-status'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(underwaterTrackAlignLocation(route.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.tune, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A scale is a correction, so "none yet" is only true
                    // without one.
                    if (route.endMode != NavTrackEndMode.none ||
                        route.scaleFactor == 1)
                      Text(_status(l10n)),
                    // The drawn track no longer matches the recorded distance
                    // above, so the page says why.
                    if (route.scaleFactor != 1)
                      Text(
                        key: const ValueKey('nav-track-detail-scale'),
                        l10n.navTrack_detail_scaleStatus(_scalePercent()),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
