import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';

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
    final anchor = route.anchor;
    final points = route.points;
    if (anchor == null || points.length < 2) return const SizedBox.shrink();

    final kinds = NavTrackSegmenter.classify(points).kinds;
    final corrected = NavTrackCorrector.apply(points, route.correction);
    final maxDepth = route.maxDepth ?? _maxDepthOf(corrected);
    // Bounded to the active range, not filtered by kind across the whole
    // recording: a diver who re-descends after a GPS fix produces more
    // `underwater` samples past the jump, and kind-filtering alone would
    // draw a second tail there and move the endpoint marker past the fix
    // (mirrors NavTrackPathAdapter's own boundary for the same reason).
    final activeStart = NavTrackCorrector.activeRangeStartIndex(points);
    final activeEnd = NavTrackCorrector.activeRangeEndIndex(points);

    LatLng geoOf(CorrectedNavTrackPoint p) {
      final geo = offsetToGeoPoint(anchor, east: p.east, north: p.north);
      return LatLng(geo.latitude, geo.longitude);
    }

    bool kept(int i) =>
        kinds[i] == NavTrackSampleKind.underwater ||
        kinds[i] == NavTrackSampleKind.surfaceReckoned;

    final polylines = <Polyline>[];
    LatLng? start;
    LatLng? end;
    CorrectedNavTrackPoint? previous;
    for (var i = activeStart; i <= activeEnd && i < corrected.length; i++) {
      if (!kept(i)) {
        previous = null;
        continue;
      }
      final p = corrected[i];
      final latLng = geoOf(p);
      start ??= latLng;
      end = latLng;
      if (previous != null) {
        final t = maxDepth <= 0
            ? 0.0
            : ((previous.depth + p.depth) / 2 / maxDepth).clamp(0.0, 1.0);
        polylines.add(
          Polyline(
            points: [geoOf(previous), latLng],
            strokeWidth: _strokeWidth,
            color: BathymetryTerrainBuilder.depthColor(t),
            strokeCap: StrokeCap.round,
          ),
        );
      }
      previous = p;
    }

    return Stack(
      children: [
        PolylineLayer(polylines: polylines),
        if (start != null)
          MarkerLayer(
            markers: [
              Marker(
                point: start,
                width: 12,
                height: 12,
                child: const _Glyph(color: Colors.green),
              ),
              if (end != null && end != start)
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

  static double _maxDepthOf(List<CorrectedNavTrackPoint> points) {
    var max = 0.0;
    for (final p in points) {
      if (p.depth > max) max = p.depth;
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
