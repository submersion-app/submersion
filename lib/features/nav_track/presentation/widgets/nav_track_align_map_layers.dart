import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_terrain_check.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_align_geometry.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A correction-target marker that reports pixel-delta drags. Fine
/// adjustment uses screen-pixel deltas converted to degrees via the local
/// Web Mercator metres-per-pixel formula rather than any flutter_map
/// internal API, so it stays independent of the package's camera
/// implementation.
///
/// Uses a raw [Listener] rather than [GestureDetector]'s `onPanUpdate`: a
/// marker sits on top of `FlutterMap`'s own pan-to-move-the-map gesture, and
/// a plain [GestureDetector] loses the gesture arena to it almost every
/// time, so the marker looked draggable but silently never moved (the drag
/// panned the map underneath it instead) -- easy to miss by eye since a
/// marker pinned to a lat/lon does not visibly detach from the map while
/// the whole view pans with it. [Listener] receives every routed pointer
/// event directly, independent of which [GestureRecognizer] wins the arena
/// for the same pointer, so the marker now actually moves every time.
class NavTrackDraggableMarker extends StatelessWidget {
  const NavTrackDraggableMarker({
    super.key,
    required this.point,
    required this.color,
    required this.keyValue,
    required this.onDrag,
  });

  final GeoPoint point;
  final Color color;
  final String keyValue;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(point.latitude, point.longitude),
          width: 36,
          height: 36,
          child: Listener(
            key: ValueKey(keyValue),
            behavior: HitTestBehavior.opaque,
            onPointerMove: (event) => onDrag(event.delta),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Marks the point on the route where the trust slider's cutoff sits: the
/// sample whose cumulative distance first reaches `trustFraction *
/// totalDistance` (design spec "The alignment page": "the trust point
/// marked on the route"). Rendered as a diamond, distinct from the green
/// start and red end glyphs, and moves live as the slider is dragged since
/// it reads straight from the in-progress [correction].
///
/// Takes the already-corrected points from the caller rather than calling
/// `NavTrackCorrector.apply` itself: this layer rebuilds on every trust
/// slider drag frame, and the correction transform is a full pass over
/// every sample in the route -- computing it again here just to index into
/// it once would duplicate work the caller (which needs the same corrected
/// array for the route polyline) already does per frame.
class NavTrackTrustMarkerLayer extends StatelessWidget {
  const NavTrackTrustMarkerLayer({
    super.key,
    required this.route,
    required this.corrected,
    required this.anchor,
    required this.activeStart,
    required this.cumulative,
    required this.trustedDistance,
  });

  final NavTrack route;
  final List<CorrectedNavTrackPoint> corrected;
  final GeoPoint anchor;
  final int activeStart;
  final List<double> cumulative;
  final double trustedDistance;

  @override
  Widget build(BuildContext context) {
    final relativeIndex = trustCutoffIndex(cumulative, trustedDistance);
    final index = activeStart + relativeIndex;
    if (index >= corrected.length) return const SizedBox.shrink();
    final p = corrected[index];
    final geo = offsetToGeoPoint(anchor, east: p.east, north: p.north);
    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(geo.latitude, geo.longitude),
          width: 20,
          height: 20,
          child: Tooltip(
            message: context.l10n.navTrack_align_trustSummary(
              trustedDistance.toStringAsFixed(0),
              ((route.points[index].timestamp -
                          route.points[activeStart].timestamp) /
                      60)
                  .round(),
            ),
            child: const _TrustGlyph(
              key: ValueKey('nav-track-align-trust-marker'),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small orange diamond -- visually distinct from the round green start
/// and red end glyphs -- marking the trust slider's cutoff point.
class _TrustGlyph extends StatelessWidget {
  const _TrustGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}

/// Renders the device's own GPS-fixed samples as yellow dots.
///
/// Deliberately built from the RAW `route.points`, never from
/// `NavTrackCorrector.apply`: a `gpsFixed` sample is the console's own
/// GPS-derived position (see the design spec, "Segments and GPS fixes"),
/// already the truth the dead-reckoned path is being corrected *against*,
/// not part of the path being corrected. Rotating it by `headingOffsetDeg`
/// or shifting it by the trust/end-point rubber band would apply a
/// correction for the console's dead-reckoning error to a position that
/// never went through dead reckoning in the first place. The dot only ever
/// moves when the anchor itself moves, since it is still expressed as a
/// local (north, east) offset from the recording's own origin.
class NavTrackGpsFixDotsLayer extends StatelessWidget {
  const NavTrackGpsFixDotsLayer({
    super.key,
    required this.route,
    required this.anchor,
  });

  final NavTrack route;
  final GeoPoint anchor;

  @override
  Widget build(BuildContext context) {
    final kinds = NavTrackSegmenter.classify(route.points).kinds;
    final points = route.points;
    final markers = <Marker>[
      for (var i = 0; i < points.length; i++)
        if (kinds[i] == NavTrackSampleKind.gpsFixed)
          Marker(
            point: LatLng(
              offsetToGeoPoint(
                anchor,
                east: points[i].east,
                north: points[i].north,
              ).latitude,
              offsetToGeoPoint(
                anchor,
                east: points[i].east,
                north: points[i].north,
              ).longitude,
            ),
            width: 6,
            height: 6,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ),
    ];
    return MarkerLayer(markers: markers);
  }
}

class NavTrackConflictDotsLayer extends StatelessWidget {
  const NavTrackConflictDotsLayer({
    super.key,
    required this.corrected,
    required this.anchor,
    required this.result,
  });

  final List<CorrectedNavTrackPoint> corrected;
  final GeoPoint anchor;
  final NavTrackTerrainCheckResult result;

  @override
  Widget build(BuildContext context) {
    final conflicts = result.conflictingIndices;
    final markers = <Marker>[
      for (final i in conflicts)
        if (i < corrected.length)
          Marker(
            point: LatLng(
              offsetToGeoPoint(
                anchor,
                east: corrected[i].east,
                north: corrected[i].north,
              ).latitude,
              offsetToGeoPoint(
                anchor,
                east: corrected[i].east,
                north: corrected[i].north,
              ).longitude,
            ),
            width: 8,
            height: 8,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
    ];
    return MarkerLayer(markers: markers);
  }
}
