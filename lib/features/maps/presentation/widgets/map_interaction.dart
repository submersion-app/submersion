import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether the reset-to-north control should be visible for [rotationDeg]
/// (degrees). Hidden within [toleranceDeg] of north (0/360).
bool shouldShowResetNorth(double rotationDeg, {double toleranceDeg = 0.5}) {
  final normalized = rotationDeg % 360; // Dart % yields [0, 360)
  final fromNorth = math.min(normalized, 360 - normalized);
  return fromNorth > toleranceDeg;
}

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

/// A self-hiding control that resets map rotation to north-up.
///
/// Placed inside [FlutterMap.children]. Reads live rotation via
/// [MapCamera.of] and resets via [MapController.of].
class MapResetNorthButton extends StatelessWidget {
  const MapResetNorthButton({super.key});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    if (!shouldShowResetNorth(camera.rotation)) {
      return const SizedBox.shrink();
    }
    final label = context.l10n.maps_resetNorth_tooltip;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: FloatingActionButton.small(
          heroTag: null,
          tooltip: label,
          onPressed: () => MapController.of(context).rotate(0),
          child: Transform.rotate(
            angle: camera.rotation * math.pi / 180,
            child: Semantics(label: label, child: const Icon(Icons.navigation)),
          ),
        ),
      ),
    );
  }
}
