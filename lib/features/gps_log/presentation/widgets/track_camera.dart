import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';

/// How to frame a track, expressed so an antimeridian crossing cannot crash.
///
/// flutter_map's LatLngBounds asserts `east <= 180`, so a track running from
/// 179.9 E to 179.9 W - which [trackBounds] correctly reports as a 0.2 deg
/// span with maxLon 180.1 - cannot be expressed as bounds AT ALL. Those
/// tracks get a centre and a zoom instead; everything else keeps the tighter
/// bounds fit.
class TrackCamera {
  const TrackCamera({this.fit, this.center, this.zoom});

  final CameraFit? fit;
  final LatLng? center;
  final double? zoom;

  /// Re-frames an already-mounted map.
  ///
  /// MapOptions.initialCameraFit is applied ONCE, behind a latch that only
  /// reopens on a size change, and didUpdateWidget preserves the camera via
  /// camera.withOptions. So a new fit passed as an option after first layout
  /// does nothing: the filter changing, a trim landing, or the track arriving
  /// after an AsyncLoading frame would all leave the old framing. Every other
  /// map in this repo drives the camera imperatively for the same reason.
  void applyTo(MapController controller) {
    final f = fit;
    if (f != null) {
      controller.fitCamera(f);
      return;
    }
    final c = center;
    final z = zoom;
    if (c != null && z != null) controller.move(c, z);
  }

  /// Null when there is nothing to frame.
  static TrackCamera? forPoints(
    List<GpsTrackPoint> points, {
    double maxZoom = 16.0,
    EdgeInsets padding = const EdgeInsets.all(48),
  }) {
    final bounds = trackBounds(points);
    if (bounds == null) return null;

    if (!crossesAntimeridian(bounds)) {
      return TrackCamera(
        fit: CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(bounds.minLat, bounds.minLon),
            LatLng(bounds.maxLat, bounds.maxLon),
          ),
          padding: padding,
          // A track a few hundred metres wide would otherwise fit past the
          // tile provider's max zoom and render blank.
          maxZoom: maxZoom,
        ),
      );
    }

    // Centre computed in the unwrapped frame, then wrapped back so the value
    // handed to flutter_map is a legal longitude.
    final centerLon = normalizeLongitude((bounds.minLon + bounds.maxLon) / 2);
    final centerLat = (bounds.minLat + bounds.maxLat) / 2;
    final corners = [
      LatLng(bounds.minLat, normalizeLongitude(bounds.minLon)),
      LatLng(bounds.maxLat, normalizeLongitude(bounds.maxLon)),
    ];
    final zoom = calculateZoomForBounds(
      corners,
      // Span in the unwrapped frame, which is the real extent.
      LatLngBounds(
        LatLng(bounds.minLat, 0),
        LatLng(bounds.maxLat, bounds.maxLon - bounds.minLon),
      ),
    );

    return TrackCamera(
      center: LatLng(centerLat, centerLon),
      zoom: zoom > maxZoom ? maxZoom : zoom,
    );
  }
}
