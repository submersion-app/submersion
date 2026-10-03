import 'package:flutter/material.dart';

import 'package:submersion/features/gps_log/presentation/widgets/gps_record_card.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_date_filter_action.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_kind_filter_control.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_empty_state.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_pending_choice_banner.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_summary_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Everything above the rows. Scrolls with them, so it never steals height
/// from a narrow pane.
class TracksListHeader extends StatelessWidget {
  const TracksListHeader({
    super.key,
    required this.showControls,
    required this.isEmpty,
    this.onMatch,
  });

  /// The landing page shows the record card, summary, filters and Match;
  /// the map page shows rows only.
  final bool showControls;
  final bool isEmpty;
  final VoidCallback? onMatch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showControls) ...[
            if (canRecordGpsTracks) ...[
              const GpsRecordCard(),
              const SizedBox(height: 16),
            ],
            const TracksSummaryStrip(),
            const TracksPendingChoiceBanner(),
            const SizedBox(height: 12),
            const TrackKindFilterControl(),
            const SizedBox(height: 8),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: GpsTrackDateFilterAction(),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('tracks-match'),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l10n.gpsLogger_matchButton),
              // Null while a sweep runs, which disables the button.
              onPressed: onMatch,
            ),
          ],
          if (isEmpty) const TracksEmptyState(),
        ],
      ),
    );
  }
}
