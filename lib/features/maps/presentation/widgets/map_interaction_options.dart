import 'package:flutter_map/flutter_map.dart';

/// Interaction settings for the maps that allow two-finger rotation.
///
/// `flutter_map` looks like it already guards rotation: [InteractionOptions]
/// ships a `rotationThreshold` of 20 degrees. It does not. The threshold is
/// only ever consulted while a multi-finger gesture race is running, and
/// `enableMultiFingerGestureRace` defaults to false, so the rotate handler runs
/// on every scale update and engages the moment the angle between the fingers
/// is anything but zero. Two fingers never spread at a perfectly constant
/// angle, so every pinch twisted the map a few degrees (issue #1067).
///
/// Turning the race on makes those thresholds live, so the first few
/// millimetres of a two-finger gesture decide what it is: a pinch commits to
/// zoom and pan, and a twist has to reach [_rotationThresholdDegrees] before it
/// rotates anything. The trade-off is that a gesture can no longer start as a
/// zoom and become a rotation partway through, which is the whole point.
///
/// Maps that should never rotate do not need this; they clear
/// [InteractiveFlag.rotate] instead, which skips the rotate handler outright.
const InteractionOptions rotatableMapInteraction = InteractionOptions(
  enableMultiFingerGestureRace: true,
  rotationThreshold: _rotationThresholdDegrees,
  // Once a twist is deliberate enough to win, hand the rest of the gesture
  // back to zoom and pan so the same two fingers can still do everything. Only
  // the reverse order is blocked, which is what stops the incidental rotation.
  rotationWinGestures: MultiFingerGesture.all,
  pinchZoomThreshold: _pinchZoomThresholdZoomLevels,
  pinchMoveThreshold: _pinchMoveThresholdPixels,
);

/// How far the line between two fingers must twist before the gesture counts
/// as a rotation. Roughly the deliberate quarter-turn of the wrist that Google
/// Maps asks for, and far beyond the few degrees a pinch wobbles through.
const double _rotationThresholdDegrees = 15.0;

/// How far a pinch must scale before it counts as a zoom, in zoom levels.
///
/// `flutter_map` defaults this to 0.5, which is a 41% change in finger
/// separation: with the race enabled that would leave the map inert for most
/// of a pinch. 0.05 is about 3.5%, so zoom claims the gesture almost
/// immediately and rotation loses cleanly.
const double _pinchZoomThresholdZoomLevels = 0.05;

/// How far the midpoint between two fingers must travel before the gesture
/// counts as a two-finger pan, in logical pixels. Lowered from the package
/// default of 40 for the same reason as the zoom threshold: under a race, a
/// large threshold reads as lag.
const double _pinchMoveThresholdPixels = 12.0;
