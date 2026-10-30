import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';

/// One sample [NavTrackPolylineLayer] draws: its [index] in the raw
/// recording (a gap between two consecutive samples' indices is a break in
/// the line), its corrected point, and where that point lands on the map.
typedef NavTrackDrawnSample = ({
  int index,
  CorrectedNavTrackPoint point,
  LatLng latLng,
});

/// Every sample [NavTrackPolylineLayer] draws for [route], in order.
///
/// Bounded to the active range, not filtered by kind across the whole
/// recording: a diver who re-descends after a GPS fix produces more
/// `underwater` samples past the jump, and kind-filtering alone would draw
/// a second tail there and move the endpoint marker past the fix (mirrors
/// NavTrackPathAdapter's own boundary for the same reason). Within that
/// range only underwater and surface-reckoned samples are kept.
///
/// The one walk both the layer and a map that embeds it read (through
/// [navTrackDrawnPoints]), so the extent a camera fits to can never drift
/// from what is drawn. Empty without an anchor or with fewer than two
/// points.
List<NavTrackDrawnSample> navTrackDrawnSamples(NavTrack route) {
  final anchor = route.anchor;
  final points = route.points;
  if (anchor == null || points.length < 2) return const [];

  // Classified once: the kind filter and the active range share it.
  final segmentation = NavTrackSegmenter.classify(points);
  final kinds = segmentation.kinds;
  final range = NavTrackCorrector.activeRangeOf(segmentation, points.length);
  final corrected = NavTrackCorrector.apply(points, route.correction);

  final samples = <NavTrackDrawnSample>[];
  for (var i = range.start; i <= range.end && i < corrected.length; i++) {
    final kind = kinds[i];
    if (kind != NavTrackSampleKind.underwater &&
        kind != NavTrackSampleKind.surfaceReckoned) {
      continue;
    }
    final p = corrected[i];
    final geo = offsetToGeoPoint(anchor, east: p.east, north: p.north);
    samples.add((
      index: i,
      point: p,
      latLng: LatLng(geo.latitude, geo.longitude),
    ));
  }
  return samples;
}

/// The map positions of [navTrackDrawnSamples], so a map embedding the layer
/// can fit its camera to the whole drawn route rather than a fixed zoom on
/// the anchor alone (which cut a long route off at the map's edge).
List<LatLng> navTrackDrawnPoints(NavTrack route) => [
  for (final sample in navTrackDrawnSamples(route)) sample.latLng,
];

/// Draws a route on a flutter_map map, depth-coloured and thinner than
/// `GpsTrackPolylineLayer` (spec 2026-09-10-underwater-nav-track-design.md,
/// "2D map integration"): a route is an underwater instrument recording, not
/// a surface support path, and the two must read differently at a glance.
///
/// Renders nothing when [route] has no anchor -- there is no map position to
/// draw at without one, and the caller shows "Set the start point..." text
/// instead of this layer. Segments never bridge a fix event or an
/// out-of-water run, matching `NavTrackPathAdapter`'s rule for the 3D ribbon.
class NavTrackPolylineLayer extends StatelessWidget {
  const NavTrackPolylineLayer({super.key, required this.route});

  final NavTrack route;

  static const double _strokeWidth = 2.5;

  @override
  Widget build(BuildContext context) {
    final samples = navTrackDrawnSamples(route);
    if (samples.isEmpty) return const SizedBox.shrink();

    final maxDepth = route.maxDepth ?? _maxDepthOf(samples);
    final polylines = <Polyline>[];
    for (var i = 1; i < samples.length; i++) {
      final previous = samples[i - 1];
      final current = samples[i];
      // A sample skipped between these two (an out-of-water run inside the
      // active range) breaks the line instead of being bridged.
      if (current.index != previous.index + 1) continue;
      final depth = (previous.point.depth + current.point.depth) / 2;
      final t = maxDepth <= 0 ? 0.0 : (depth / maxDepth).clamp(0.0, 1.0);
      polylines.add(
        Polyline(
          points: [previous.latLng, current.latLng],
          strokeWidth: _strokeWidth,
          color: BathymetryTerrainBuilder.depthColor(t),
          strokeCap: StrokeCap.round,
        ),
      );
    }

    final start = samples.first.latLng;
    final end = samples.last.latLng;
    return Stack(
      children: [
        PolylineLayer(polylines: polylines),
        MarkerLayer(
          markers: [
            Marker(
              point: start,
              width: 12,
              height: 12,
              child: const _Glyph(color: Colors.green),
            ),
            if (end != start)
              Marker(
                point: end,
                width: 12,
                height: 12,
                child: const _Glyph(color: Colors.red),
              ),
          ],
        ),
      ],
    );
  }

  /// The colour scale for a row stored before its max depth was: the
  /// deepest drawn sample, over the same active range the stored value
  /// (`NavTrackStats.maxDepth`) covers.
  static double _maxDepthOf(List<NavTrackDrawnSample> samples) {
    var max = 0.0;
    for (final s in samples) {
      if (s.point.depth > max) max = s.point.depth;
    }
    return max;
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
