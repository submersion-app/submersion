import 'package:flutter_map/flutter_map.dart';

/// Builds flutter_map [InteractionOptions] from the active pointer kind.
///
/// Touch keeps flutter_map's native pinch (focal-point zoom). Trackpad/mouse
/// drop the multi-finger and fling paths because [MapInteractionDetector]
/// drives trackpad zoom-to-cursor itself; mouse-wheel zoom and click-drag pan
/// stay with flutter_map.
InteractionOptions mapInteractionOptions({
  required bool isTouch,
  required bool allowRotation,
}) {
  final gestureRotate = allowRotation && isTouch;

  final int flags;
  if (isTouch) {
    flags =
        InteractiveFlag.drag |
        InteractiveFlag.flingAnimation |
        InteractiveFlag.pinchMove |
        InteractiveFlag.pinchZoom |
        InteractiveFlag.doubleTapZoom |
        InteractiveFlag.doubleTapDragZoom |
        InteractiveFlag.scrollWheelZoom |
        (gestureRotate ? InteractiveFlag.rotate : 0);
  } else {
    flags =
        InteractiveFlag.drag |
        InteractiveFlag.doubleTapZoom |
        InteractiveFlag.doubleTapDragZoom |
        InteractiveFlag.scrollWheelZoom;
  }

  return InteractionOptions(
    flags: flags,
    enableMultiFingerGestureRace: gestureRotate,
    rotationThreshold: 30.0,
    cursorKeyboardRotationOptions: allowRotation
        ? const CursorKeyboardRotationOptions()
        : CursorKeyboardRotationOptions.disabled(),
  );
}
