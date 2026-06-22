import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/ui/trackpad_zoom_recognizer.dart';

/// Wraps a [FlutterMap] so a two-finger gesture on a trackpad zooms the map
/// toward the cursor: vertical scroll and pinch both zoom.
///
/// It installs a [TrackpadZoomGestureRecognizer] that eagerly wins the gesture
/// arena for trackpad pan-zoom. Winning rejects flutter_map's own scale
/// recognizer (so it never pins the camera and reverts our zoom) and rejects any
/// enclosing scrollable (so a scroll over an embedded map zooms the map instead
/// of scrolling the page). Trackpad click-drag, mouse, and touch still flow to
/// flutter_map untouched, and the mouse wheel still zooms via flutter_map's own
/// pointer-signal handling.
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
        TrackpadZoomGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TrackpadZoomGestureRecognizer>(
              () => TrackpadZoomGestureRecognizer(debugOwner: this),
              (recognizer) => recognizer.onZoom = _applyZoom,
            ),
      },
      child: child,
    );
  }
}
