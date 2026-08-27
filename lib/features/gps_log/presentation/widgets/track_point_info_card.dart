import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Finds the recorded fix nearest [tapped] within the span [run] covers.
///
/// Searches [fullPoints] rather than the run's own (simplified) points: a tap
/// must report a real recorded fix with its real timestamp and accuracy, not
/// whichever survivor of decimation happened to land nearby. The run only
/// bounds the search window.
({GpsTrackPoint point, double speedMps})? nearestPointInRun({
  required List<GpsTrackPoint> fullPoints,
  required TrackRun run,
  required LatLng tapped,
}) {
  if (run.points.isEmpty || fullPoints.isEmpty) return null;

  final fromTime = run.points.first.timestamp;
  final toTime = run.points.last.timestamp;
  final target = GeoPoint(tapped.latitude, tapped.longitude);

  GpsTrackPoint? best;
  var bestIndex = -1;
  var bestDistance = double.infinity;

  for (var i = 0; i < fullPoints.length; i++) {
    final candidate = fullPoints[i];
    if (candidate.timestamp < fromTime || candidate.timestamp > toTime) {
      continue;
    }
    final d = distanceMeters(toGeoPoint(candidate), target);
    if (d < bestDistance) {
      bestDistance = d;
      best = candidate;
      bestIndex = i;
    }
  }

  if (best == null) return null;
  final speed = bestIndex > 0
      ? speedMpsBetween(fullPoints[bestIndex - 1], best)
      : 0.0;
  return (point: best, speedMps: speed);
}

/// Shows the timestamp, speed, and accuracy of a tapped fix.
class TrackPointInfoCard extends ConsumerWidget {
  const TrackPointInfoCard({
    super.key,
    required this.point,
    required this.speedMps,
    required this.onDismiss,
  });

  final GpsTrackPoint point;
  final double speedMps;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));

    // Wall-clock-as-UTC: format the UTC components directly. Calling
    // toLocal() here would shift every displayed time by the viewing
    // device's offset.
    final time = DateTime.fromMillisecondsSinceEpoch(
      point.timestamp * 1000,
      isUtc: true,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    units.formatTimeWithSeconds(time),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.gpsTrack_inspect_speed}: '
                    '${units.formatSpeed(speedMps)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (point.accuracy != null)
                    Text(
                      '${l10n.gpsTrack_inspect_accuracy}: '
                      '${units.formatDistance(point.accuracy!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('track-inspect-close'),
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
          ],
        ),
      ),
    );
  }
}
