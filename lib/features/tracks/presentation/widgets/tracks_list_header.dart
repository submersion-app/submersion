import 'package:flutter/material.dart';

import 'package:submersion/features/gps_log/presentation/widgets/gps_record_card.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_date_filter_action.dart';
import 'package:submersion/features/tracks/domain/tracks_query.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_kind_filter_control.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_empty_state.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_summary_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Everything above the rows. Scrolls with them, so it never steals height
/// from a narrow pane.
class TracksListHeader extends StatelessWidget {
  const TracksListHeader({
    super.key,
    required this.showControls,
    required this.truncated,
    required this.isEmpty,
    this.onMatch,
  });

  /// The landing page shows the record card, summary, filters and Match;
  /// the map page shows rows and the cap notice only.
  final bool showControls;
  final bool truncated;
  final bool isEmpty;
  final VoidCallback? onMatch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final match = onMatch;
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
            const SizedBox(height: 12),
            const TrackKindFilterControl(),
            const SizedBox(height: 8),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: GpsTrackDateFilterAction(),
            ),
            if (match != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('tracks-match'),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(l10n.tracks_match_button),
                onPressed: match,
              ),
            ],
          ],
          if (truncated) ...[
            const SizedBox(height: 12),
            Text(
              l10n.gpsTrack_map_truncated(kTracksOverviewLimit),
              key: const ValueKey('tracks-truncated-notice'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (isEmpty) const TracksEmptyState(),
        ],
      ),
    );
  }
}
