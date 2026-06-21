import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Builds flutter_map [InteractionOptions] from the active pointer kind.
///
/// Rotation is disabled on all maps (issue #238: accidental rotation was the
/// complaint, and flutter_map cannot provide a usable rotation deadband).
///
/// Touch keeps flutter_map's native pinch (focal-point zoom, which is correct
/// on real touch input). Trackpad/mouse drop the multi-finger and fling paths
/// because [MapInteractionDetector] drives trackpad zoom-to-cursor itself;
/// mouse-wheel zoom and click-drag pan stay with flutter_map.
InteractionOptions mapInteractionOptions({required bool isTouch}) {
  final int flags;
  if (isTouch) {
    flags =
        InteractiveFlag.drag |
        InteractiveFlag.flingAnimation |
        InteractiveFlag.pinchMove |
        InteractiveFlag.pinchZoom |
        InteractiveFlag.doubleTapZoom |
        InteractiveFlag.doubleTapDragZoom |
        InteractiveFlag.scrollWheelZoom;
  } else {
    flags =
        InteractiveFlag.drag |
        InteractiveFlag.doubleTapZoom |
        InteractiveFlag.doubleTapDragZoom |
        InteractiveFlag.scrollWheelZoom;
  }

  return InteractionOptions(
    flags: flags,
    // Rotation is disabled: no rotate gesture flag above, and Ctrl+drag cursor
    // rotation is turned off too. keyboardOptions defaults already disable QE
    // rotation.
    cursorKeyboardRotationOptions: CursorKeyboardRotationOptions.disabled(),
  );
}

/// Wraps a [FlutterMap] to (1) choose [InteractionOptions] from the active
/// pointer kind and (2) drive trackpad zoom-to-cursor.
///
/// The map built by [builder] must fill this widget's box so that pointer
/// `localPosition` is in the map viewport coordinate space.
class MapInteractionDetector extends StatefulWidget {
  const MapInteractionDetector({
    super.key,
    required this.mapController,
    required this.builder,
  });

  final MapController mapController;
  final Widget Function(BuildContext context, InteractionOptions options)
  builder;

  @override
  State<MapInteractionDetector> createState() => _MapInteractionDetectorState();
}

class _MapInteractionDetectorState extends State<MapInteractionDetector> {
  late bool _isTouch = _defaultIsTouch();

  /// Last known pointer position from reliable hover/move/down events, in the
  /// map viewport's local coordinate space. Used as the trackpad zoom anchor
  /// because `PointerPanZoom*` events report an unreliable `localPosition` on
  /// some platforms (e.g. macOS trackpad pinch; see flutter/flutter#136029) —
  /// the gesture's scale/pan deltas are fine, but its absolute focal position
  /// is not, which made pinch zoom fly to a wrong point.
  Offset? _lastPointerPosition;

  double _gestureStartZoom = 0;
  Offset _gestureAnchor = Offset.zero;
  Offset _lastPan = Offset.zero;

  bool _defaultIsTouch() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  void _setTouch(bool value) {
    if (_isTouch != value) {
      setState(() => _isTouch = value);
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    _lastPointerPosition = e.localPosition;
    _setTouch(e.kind == PointerDeviceKind.touch);
  }

  void _onPointerHover(PointerHoverEvent e) {
    _lastPointerPosition = e.localPosition;
    _setTouch(e.kind == PointerDeviceKind.touch);
  }

  void _onPointerMove(PointerMoveEvent e) {
    _lastPointerPosition = e.localPosition;
  }

  static Offset _rotateOffset(Offset offset, double radians) {
    if (radians == 0) return offset;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Offset(
      cos * offset.dx + sin * offset.dy,
      cos * offset.dy - sin * offset.dx,
    );
  }

  void _onPanZoomStart(PointerPanZoomStartEvent e) {
    _setTouch(false);
    final cam = widget.mapController.camera;
    _gestureStartZoom = cam.zoom;
    // Anchor on the last reliable pointer position (the cursor), NOT
    // e.localPosition, which is unreliable for pan/zoom events. Fall back to
    // the viewport center so a missing hover never produces a bogus jump.
    _gestureAnchor =
        _lastPointerPosition ?? cam.nonRotatedSize.center(Offset.zero);
    _lastPan = Offset.zero;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e) {
    final cam = widget.mapController.camera;
    final targetZoom = cam.clampZoom(
      _gestureStartZoom + math.log(e.scale) / math.ln2,
    );
    var center = cam.focusedZoomCenter(_gestureAnchor, targetZoom);

    final panDelta = e.localPan - _lastPan;
    _lastPan = e.localPan;
    if (panDelta != Offset.zero) {
      final projected = cam.projectAtZoom(center, targetZoom);
      center = cam.unprojectAtZoom(
        projected - _rotateOffset(panDelta, cam.rotationRad),
        targetZoom,
      );
    }
    widget.mapController.move(center, targetZoom);
  }

  @override
  Widget build(BuildContext context) {
    final options = mapInteractionOptions(isTouch: _isTouch);
    return Listener(
      // Opaque hit-testing ensures trackpad pan/zoom and hover events reach
      // this detector even over transparent regions of the map.
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerHover: _onPointerHover,
      onPointerMove: _onPointerMove,
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      child: widget.builder(context, options),
    );
  }
}
