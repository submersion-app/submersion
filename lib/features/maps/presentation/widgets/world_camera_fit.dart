import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';

/// Fits the camera to every one of [points], going the short way round the
/// globe.
///
/// [CameraFit.bounds] cannot frame points on both sides of the date line:
/// a [LatLngBounds] has to stay inside -180..180, so a box around Australia
/// and Tahiti spans Africa instead of the Pacific (issue #2516). This fit
/// finds the narrowest longitude band with [shortestLongitudeSpan], moves
/// the points so that band is centred on Greenwich, lets [CameraFit.bounds]
/// frame them there, and moves the result back. Web Mercator looks the same
/// at every longitude, so the zoom it picks is exact.
///
/// The bounds are padded by ten percent of each span first, as
/// [boundsForPoints] does, then by [padding] on screen. A set of points that
/// all sit on one spot is centred at [singlePointZoom] instead (never past
/// [maxZoom]), since a zero-area box has no finite zoom. Unusable points (see
/// [isUsableMapPoint]) are skipped; with none left the camera is unchanged.
@immutable
class WorldCameraFit extends CameraFit {
  const WorldCameraFit({
    required this.points,
    this.padding = EdgeInsets.zero,
    this.maxZoom,
    this.singlePointZoom = 12.0,
  });

  final List<LatLng> points;
  final EdgeInsets padding;
  final double? maxZoom;
  final double singlePointZoom;

  @override
  MapCamera fit(MapCamera camera) {
    final usable = points.where(isUsableMapPoint).toList();
    final span = shortestLongitudeSpan(usable.map((p) => p.longitude));
    if (span == null) return camera;

    final middle = (span.west + span.east) / 2;
    final centred = [
      for (final p in usable)
        LatLng(p.latitude, longitudeDelta(middle, p.longitude)),
    ];
    final bounds = boundsForPoints(centred)!;
    if (bounds.north == bounds.south && bounds.east == bounds.west) {
      return camera.withPosition(
        center: LatLng(bounds.north, normalizeLongitude(middle)),
        zoom: math.min(singlePointZoom, maxZoom ?? singlePointZoom),
      );
    }

    final fitted = CameraFit.bounds(
      bounds: bounds,
      padding: padding,
      maxZoom: maxZoom,
    ).fit(camera);
    return fitted.withPosition(
      center: LatLng(
        fitted.center.latitude,
        normalizeLongitude(fitted.center.longitude + middle),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorldCameraFit &&
      listEquals(other.points, points) &&
      other.padding == padding &&
      other.maxZoom == maxZoom &&
      other.singlePointZoom == singlePointZoom;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(points), padding, maxZoom, singlePointZoom);
}
