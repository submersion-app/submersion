import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';
import 'package:submersion/features/maps/presentation/widgets/world_camera_fit.dart';

MapCamera _camera() => MapCamera(
  crs: const Epsg3857(),
  center: const LatLng(0, 0),
  zoom: 2,
  rotation: 0,
  nonRotatedSize: const Size(800, 600),
  minZoom: 2,
  maxZoom: 18,
);

void main() {
  test('frames Australia and the Pacific across the date line', () {
    // The reporter's case in issue #2516: a plain bounding box of these
    // three sites centres on 15E, which is Africa.
    const points = [
      LatLng(-16.9, 150.0), // Queensland
      LatLng(-17.7, 178.0), // Fiji
      LatLng(-17.5, -149.0), // Tahiti
    ];

    final fitted = const WorldCameraFit(points: points).fit(_camera());

    // The span runs 150E to 211E (149W), so its middle is 180.5E.
    expect(longitudeDelta(fitted.center.longitude, 180.5).abs(), lessThan(1.0));
    expect(fitted.center.latitude, closeTo(-17.3, 1.0));
    // A 61-degree span fits well inside one screen, so the fit zooms in
    // past the world view.
    expect(fitted.zoom, greaterThan(3));
  });

  test('matches a plain bounds fit when nothing crosses the date line', () {
    const points = [LatLng(10, -80), LatLng(20, -60)];
    const padding = EdgeInsets.all(50);

    final wrapped = const WorldCameraFit(
      points: points,
      padding: padding,
    ).fit(_camera());
    final plain = CameraFit.bounds(
      bounds: boundsForPoints(points)!,
      padding: padding,
    ).fit(_camera());

    expect(wrapped.center.latitude, closeTo(plain.center.latitude, 1e-6));
    expect(wrapped.center.longitude, closeTo(plain.center.longitude, 1e-6));
    expect(wrapped.zoom, closeTo(plain.zoom, 1e-6));
  });

  test('centres a single point at the single-point zoom', () {
    final fitted = const WorldCameraFit(
      points: [LatLng(-8.5, 115.2)],
      singlePointZoom: 12,
    ).fit(_camera());

    expect(fitted.center.latitude, closeTo(-8.5, 1e-9));
    expect(fitted.center.longitude, closeTo(115.2, 1e-9));
    expect(fitted.zoom, 12);
  });

  test('holds a single point to maxZoom when that is lower', () {
    final fitted = const WorldCameraFit(
      points: [LatLng(-8.5, 115.2)],
      maxZoom: 9,
    ).fit(_camera());

    expect(fitted.zoom, 9);
  });

  test('leaves the camera alone when no point is usable', () {
    final camera = _camera();
    final fitted = const WorldCameraFit(
      points: [LatLng(double.nan, 0), LatLng(95, 0)],
    ).fit(camera);

    expect(identical(fitted, camera), isTrue);
  });

  test('never zooms past maxZoom', () {
    final fitted = const WorldCameraFit(
      points: [LatLng(10, 10), LatLng(10.0001, 10.0001)],
      maxZoom: 14,
    ).fit(_camera());

    expect(fitted.zoom, lessThanOrEqualTo(14));
  });

  test('compares by value so rebuilt map options stay equal', () {
    const a = WorldCameraFit(points: [LatLng(1, 2)], maxZoom: 10);
    const b = WorldCameraFit(points: [LatLng(1, 2)], maxZoom: 10);
    const c = WorldCameraFit(points: [LatLng(1, 3)], maxZoom: 10);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}
