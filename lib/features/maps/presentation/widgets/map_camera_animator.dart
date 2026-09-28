import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/domain/map_utils.dart';
import 'package:submersion/features/maps/presentation/widgets/world_camera_fit.dart';

/// Animated camera moves shared by the app's maps.
///
/// The dive, site, dive-center, activity and media maps all move their
/// cameras through this (issue #2330), so they share durations, paddings and
/// the short way across the date line (issue #2516). [dispose] cancels an
/// in-flight animation, which the per-call `AnimationController`s the maps
/// used to carry could not do.
///
/// Every method needs [controller] attached to a mounted `FlutterMap`;
/// call them from `onMapReady` or later.
class MapCameraAnimator {
  MapCameraAnimator({required this.controller, required this.vsync});

  final MapController controller;
  final TickerProvider vsync;

  AnimationController? _inFlight;
  CurvedAnimation? _inFlightCurve;

  /// Eases to [target] over [duration]. Zooms in to 12 when the camera is
  /// wider than zoom 10; otherwise keeps the current zoom.
  Future<void> animateTo(
    LatLng target, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final start = controller.camera;
    final targetZoom = start.zoom < 10 ? 12.0 : start.zoom;
    return _run(start, target, targetZoom, duration);
  }

  /// Eases to a camera that shows [bounds] with [padding], never closer
  /// than [maxZoom].
  Future<void> animateToBounds(
    LatLngBounds bounds, {
    EdgeInsets padding = const EdgeInsets.all(120),
    double maxZoom = 14.0,
    Duration duration = const Duration(milliseconds: 800),
  }) {
    final start = controller.camera;
    final target = CameraFit.bounds(
      bounds: bounds,
      padding: padding,
      maxZoom: maxZoom,
    ).fit(start);
    return _run(start, target.center, target.zoom, duration);
  }

  /// Jumps (no animation) to show every point: a single point at
  /// [singlePointZoom], otherwise the padded bounds, crossing the date line
  /// when that frames them tighter (see [WorldCameraFit]). Empty input and
  /// input with no in-range point are no-ops. Any in-flight animation is
  /// cancelled first, so it cannot keep moving the camera and undo the fit.
  void fitAll(
    List<LatLng> points, {
    double singlePointZoom = 12.0,
    EdgeInsets padding = const EdgeInsets.all(50),
  }) {
    final fit = fitAllCameraFit(
      points,
      singlePointZoom: singlePointZoom,
      padding: padding,
    );
    if (fit == null) return;
    dispose();
    controller.fitCamera(fit);
  }

  /// The camera [fitAll] jumps to, as a [CameraFit] a map can pass to
  /// `MapOptions.initialCameraFit` so it opens framed the way its fit-all
  /// button frames it. Null when no point is usable.
  static CameraFit? fitAllCameraFit(
    List<LatLng> points, {
    double singlePointZoom = 12.0,
    EdgeInsets padding = const EdgeInsets.all(50),
  }) {
    final usable = points.where(isUsableMapPoint).toList();
    if (usable.isEmpty) return null;
    return WorldCameraFit(
      points: usable,
      padding: padding,
      singlePointZoom: singlePointZoom,
    );
  }

  /// Cancels any in-flight animation. Safe to call twice.
  void dispose() {
    final current = _inFlight;
    final curve = _inFlightCurve;
    _inFlight = null;
    _inFlightCurve = null;
    curve?.dispose();
    current?.stop();
    current?.dispose();
  }

  Future<void> _run(
    MapCamera start,
    LatLng targetCenter,
    double targetZoom,
    Duration duration,
  ) {
    // A new move supersedes the previous one.
    dispose();

    final animation = AnimationController(duration: duration, vsync: vsync);
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    _inFlight = animation;
    _inFlightCurve = curve;

    curve.addListener(() {
      final t = curve.value;
      final lat =
          start.center.latitude +
          (targetCenter.latitude - start.center.latitude) * t;
      // The short way round, so a move from Fiji to Samoa crosses the date
      // line instead of sweeping back across the whole world.
      final lng = normalizeLongitude(
        start.center.longitude +
            longitudeDelta(start.center.longitude, targetCenter.longitude) * t,
      );
      final zoom = start.zoom + (targetZoom - start.zoom) * t;
      controller.move(LatLng(lat, lng), zoom);
    });

    final done = Completer<void>();
    // whenCompleteOrCancel fires on natural completion and on cancellation
    // (dispose stops the ticker). A cancelled controller has already been
    // disposed by [dispose], so only tear down one that is still ours.
    animation.forward().whenCompleteOrCancel(() {
      if (identical(_inFlight, animation)) {
        _inFlight = null;
        _inFlightCurve = null;
        curve.dispose();
        animation.dispose();
      }
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }
}
