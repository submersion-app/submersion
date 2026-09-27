import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/domain/map_utils.dart';

/// Animated camera moves shared by the app's maps.
///
/// The dive, site and dive-center maps each carry private copies of these
/// three moves with identical durations and paddings; the defaults here are
/// those values verbatim so migrating them (issue #2330) is
/// behaviour-preserving. One improvement over the copies: [dispose] cancels
/// an in-flight animation, which a per-call `AnimationController` that is
/// only disposed after `forward()` completes cannot do.
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
  /// [singlePointZoom], otherwise the padded bounds. Empty input and input
  /// with no in-range point are no-ops. Any in-flight animation is cancelled
  /// first, so it cannot keep moving the camera and undo the fit.
  void fitAll(
    List<LatLng> points, {
    double singlePointZoom = 12.0,
    EdgeInsets padding = const EdgeInsets.all(50),
  }) {
    final usable = points.where(isUsableMapPoint).toList();
    if (usable.isEmpty) return;
    dispose();
    if (usable.length == 1) {
      controller.move(usable.single, singlePointZoom);
      return;
    }
    final bounds = boundsForPoints(usable);
    if (bounds == null) return;
    controller.fitCamera(CameraFit.bounds(bounds: bounds, padding: padding));
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
      final lng =
          start.center.longitude +
          (targetCenter.longitude - start.center.longitude) * t;
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
