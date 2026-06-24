import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import 'package:submersion/core/ui/trackpad_zoom.dart';

/// Recognizes a trackpad two-finger gesture (pan-zoom) and reports a zoom-level
/// delta combining vertical scroll and pinch, anchored at the pointer.
///
/// Install it via a `RawGestureDetector` around any zoomable widget (a map, the
/// dive profile chart). It accepts the gesture *eagerly*, so it wins the gesture
/// arena. Winning does two jobs at once:
///
///  1. the host widget's own scale recognizer (e.g. flutter_map's) is rejected,
///     so it cannot fight the zoom we apply, and
///  2. an enclosing scrollable is rejected, so a scroll over the widget zooms it
///     instead of scrolling the page ("capture the gesture when hovered").
///
/// It claims only trackpad pan-zoom: [addAllowedPointer] is intentionally a
/// no-op, so ordinary pointers (mouse, touch, and even a trackpad click-drag)
/// are left to other recognizers. Touch pinch (two ordinary pointers) and the
/// mouse wheel (a pointer signal) are therefore unaffected.
class TrackpadZoomGestureRecognizer extends OneSequenceGestureRecognizer {
  TrackpadZoomGestureRecognizer({super.debugOwner})
    : super(supportedDevices: const {PointerDeviceKind.trackpad});

  /// Called per update with the pointer's local position and an additive
  /// zoom-level delta (positive = zoom in). Map consumers add it to
  /// `camera.zoom`; the dive profile chart applies `pow(2, delta)` as a factor.
  void Function(Offset localPosition, double zoomDelta)? onZoom;

  double _lastScale = 1.0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // Do not claim ordinary pointers (e.g. trackpad click-drag) — those should
    // pan via the host widget.
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    super.addAllowedPointerPanZoom(event);
    _lastScale = 1.0;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerPanZoomUpdateEvent) {
      // Scroll contribution (vertical pan) plus pinch contribution (the change
      // in cumulative scale since the previous update, expressed in zoom levels).
      final scrollDelta = trackpadScrollZoomDelta(event.panDelta.dy);
      final scaleRatio = _lastScale == 0 ? 1.0 : event.scale / _lastScale;
      _lastScale = event.scale;
      final pinchDelta = math.log(scaleRatio) / math.ln2;
      onZoom?.call(event.localPosition, scrollDelta + pinchDelta);
    } else if (event is PointerPanZoomEndEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'trackpadZoom';
}
