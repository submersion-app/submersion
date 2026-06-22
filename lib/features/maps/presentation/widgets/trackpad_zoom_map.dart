import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/ui/trackpad_zoom.dart';

/// Wraps a [FlutterMap] so a two-finger gesture on a trackpad zooms the map
/// toward the cursor: vertical scroll and pinch both zoom.
///
/// It installs a [GestureRecognizer] that *eagerly wins* the gesture arena for
/// trackpad pan-zoom events. Winning the arena does two jobs at once:
///
///  1. flutter_map's own scale recognizer is rejected, so it never pins the
///     camera to the gesture start (which would revert our zoom), and
///  2. an enclosing scrollable (e.g. a details page) is also rejected, so a
///     scroll over the map zooms the map instead of scrolling the page
///     ("map captures the gesture when hovered").
///
/// Only trackpad pan-zoom is captured. Trackpad click-drag, mouse, and touch
/// still flow to flutter_map untouched (touch pinch, one-finger pan), and the
/// mouse wheel still zooms via flutter_map's own pointer-signal handling.
class TrackpadZoomMap extends StatelessWidget {
  const TrackpadZoomMap({
    super.key,
    required this.controller,
    required this.child,
    this.minZoom = 1.0,
    this.maxZoom = 22.0,
  });

  /// The same controller passed to the wrapped [FlutterMap]'s `mapController`.
  final MapController controller;
  final Widget child;
  final double minZoom;
  final double maxZoom;

  void _applyZoom(Offset localPosition, double zoomDelta) {
    if (zoomDelta == 0) return;
    final MapCamera camera;
    try {
      camera = controller.camera;
    } catch (_) {
      // Controller not yet attached to a FlutterMap.
      return;
    }
    final newZoom = (camera.zoom + zoomDelta).clamp(minZoom, maxZoom);
    if (newZoom == camera.zoom) return;
    // focusedZoomCenter keeps the point under the cursor fixed; it already
    // accounts for map rotation.
    controller.move(camera.focusedZoomCenter(localPosition, newZoom), newZoom);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _TrackpadZoomGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              _TrackpadZoomGestureRecognizer
            >(
              () => _TrackpadZoomGestureRecognizer(),
              (recognizer) => recognizer.onZoom = _applyZoom,
            ),
      },
      child: child,
    );
  }
}

/// Recognizes a trackpad two-finger gesture (pan-zoom) and reports a zoom-level
/// delta combining vertical scroll and pinch, anchored at the pointer.
///
/// It claims only trackpad pan-zoom: [addAllowedPointer] is intentionally a
/// no-op so ordinary pointers (including a trackpad click-drag) are left to
/// other recognizers (flutter_map's pan). It accepts the gesture eagerly so it
/// wins the arena against flutter_map and any enclosing scrollable.
class _TrackpadZoomGestureRecognizer extends OneSequenceGestureRecognizer {
  _TrackpadZoomGestureRecognizer()
    : super(supportedDevices: const {PointerDeviceKind.trackpad});

  /// Called with the pointer's local position and an additive zoom-level delta.
  void Function(Offset localPosition, double zoomDelta)? onZoom;

  double _lastScale = 1.0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // Do not claim ordinary pointers (e.g. trackpad click-drag) — those should
    // pan via flutter_map.
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
      // Scroll contribution (vertical pan), plus pinch contribution (the change
      // in cumulative scale since the previous update, in zoom levels).
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
