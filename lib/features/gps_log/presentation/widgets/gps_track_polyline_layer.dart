import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/gps_log/domain/track_colorization.dart';

/// Sequential ramp endpoints for each colorization mode.
///
/// Speed runs cool (slow) to warm (fast); elapsed time runs light to dark in
/// the theme's primary hue. Both are generated from the active [ColorScheme]
/// rather than hard-coded so they hold up in light and dark themes.
List<Color> trackBucketColors(
  ColorScheme scheme,
  TrackColorMode mode,
  int buckets,
) {
  if (mode == TrackColorMode.uniform) return [scheme.primary];

  final (Color from, Color to) = switch (mode) {
    TrackColorMode.speed => (scheme.tertiary, scheme.error),
    TrackColorMode.elapsed => (scheme.primaryContainer, scheme.primary),
    TrackColorMode.uniform => (scheme.primary, scheme.primary),
  };

  if (buckets <= 1) return [to];
  return [
    for (var i = 0; i < buckets; i++) Color.lerp(from, to, i / (buckets - 1))!,
  ];
}

/// Converts colorization runs into one [Polyline] per run.
///
/// Each polyline carries its run index as [Polyline.hitValue] so a tap can be
/// resolved back to a specific span of the track.
List<Polyline<int>> buildTrackPolylines({
  required List<TrackRun> runs,
  required TrackColorMode mode,
  required ColorScheme scheme,
  double strokeWidth = 4.0,
  Color? uniformColor,
}) {
  if (runs.isEmpty) return const [];

  final colors = trackBucketColors(scheme, mode, kTrackColorBuckets);

  return [
    for (var i = 0; i < runs.length; i++)
      Polyline<int>(
        points: [
          for (final p in runs[i].points) LatLng(p.latitude, p.longitude),
        ],
        color: mode == TrackColorMode.uniform
            ? (uniformColor ?? colors.first)
            : colors[runs[i].bucket.clamp(0, colors.length - 1)],
        strokeWidth: strokeWidth,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
        hitValue: i,
      ),
  ];
}

/// Draws a colorized track as a flutter_map layer.
class GpsTrackPolylineLayer extends StatelessWidget {
  const GpsTrackPolylineLayer({
    super.key,
    required this.runs,
    required this.mode,
    this.strokeWidth = 4.0,
    this.uniformColor,
    this.hitNotifier,
  });

  final List<TrackRun> runs;
  final TrackColorMode mode;
  final double strokeWidth;
  final Color? uniformColor;
  final LayerHitNotifier<int>? hitNotifier;

  @override
  Widget build(BuildContext context) {
    return PolylineLayer<int>(
      hitNotifier: hitNotifier,
      polylines: buildTrackPolylines(
        runs: runs,
        mode: mode,
        scheme: Theme.of(context).colorScheme,
        strokeWidth: strokeWidth,
        uniformColor: uniformColor,
      ),
    );
  }
}
