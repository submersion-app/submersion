import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_stat_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Summary figures for one recorded track.
///
/// Horizontally scrollable: six stat tiles will not fit a narrow phone, and
/// truncating any of them is worse than letting the row scroll.
class TrackStatsHeader extends ConsumerWidget {
  const TrackStatsHeader({
    super.key,
    required this.points,
    required this.diveCount,
  });

  final List<GpsTrackPoint> points;
  final int diveCount;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '--';
    final duration = Duration(seconds: seconds);
    if (duration.inHours < 1) return '${duration.inMinutes}min';
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));

    final distance = trackDistanceMeters(points);
    final elapsed = points.length >= 2
        ? points.last.timestamp - points.first.timestamp
        : 0;
    // Guard the zero-duration case rather than dividing into infinity.
    final avgSpeed = elapsed > 0 ? distance / elapsed : 0.0;
    final maxSpeed = speedRange(points)?.max ?? 0.0;

    final tiles = <(String, String)>[
      // formatGeoDistance, not formatDistance: a surface track is kilometres
      // long, and formatDistance is the depth-unit formatter, so a 74 km
      // crossing rendered as "74000 m".
      (l10n.gpsTrack_stats_distance, units.formatGeoDistance(distance)),
      (l10n.gpsTrack_stats_duration, _formatDuration(elapsed)),
      (l10n.gpsTrack_stats_avgSpeed, units.formatSpeed(avgSpeed)),
      (l10n.gpsTrack_stats_maxSpeed, units.formatSpeed(maxSpeed)),
      (l10n.gpsTrack_stats_fixes, '${points.length}'),
      (l10n.gpsTrack_stats_dives, '$diveCount'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final (label, value) in tiles)
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: TrackStatTile(label: label, value: value),
            ),
        ],
      ),
    );
  }
}
