import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Claims the touch gestures on the dive profile chart that fl_chart's
/// internal recognizers must not win:
///
///  - a second touch pointer landing (pinch / two-finger pan) is claimed
///    immediately, so the pinch works even when the first finger already
///    moved and fl_chart's pan recognizer owns that pointer's arena;
///  - a single-finger drag past touch slop is claimed when [isZoomed]
///    returned true at pointer-down, making "drag to pan" real on touch.
///
/// Hosted on a translucent overlay stacked directly above the [LineChart]:
/// hit-testing reaches the overlay first, so this recognizer joins each
/// pointer's arena before fl_chart's recognizers and wins ties
/// deterministically (arena membership order follows hit-test order).
///
/// Taps and long-presses are deliberately NOT claimed: a single pointer that
/// lifts without exceeding slop is resolved rejected here, letting
/// fl_chart's tap recognizer win the sweep (tooltip on tap), and a
/// long-press that fires before slop is exceeded takes the arena first
/// (long-press scrubbing keeps working while zoomed).
///
/// This recognizer only ever claims the arena; the gesture math itself lives
/// in the chart's passive [Listener], which sees every pointer event
/// regardless of arena outcomes. [onClaimed]/[onReleased] tell the chart
/// whether a touch drag is currently claimed (i.e. safe to pan).
class ChartTouchClaimRecognizer extends OneSequenceGestureRecognizer {
  ChartTouchClaimRecognizer({required this.isZoomed, super.debugOwner})
    : super(supportedDevices: {PointerDeviceKind.touch});

  /// Sampled at first pointer-down; a gesture keeps the meaning it started
  /// with even if the viewport zoom changes mid-gesture.
  final ValueGetter<bool> isZoomed;

  /// Fired once when the recognizer wins an arena (drag pan or pinch).
  VoidCallback? onClaimed;

  /// Fired when the last tracked pointer lifts after a claim.
  VoidCallback? onReleased;

  final Map<int, Offset> _downPositions = {};
  bool _claimed = false;
  bool _zoomedAtFirstDown = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    if (_downPositions.isEmpty) _zoomedAtFirstDown = isZoomed();
    _downPositions[event.pointer] = event.position;
    // Every pointer joins its own fresh arena, so each one landing into a
    // multi-touch gesture must be resolved explicitly - including pointers
    // joining an already-claimed drag or pinch (resolve() only touches
    // still-pending entries, so repeating it is safe).
    if (_downPositions.length >= 2) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent &&
        !_claimed &&
        _downPositions.length == 1 &&
        _zoomedAtFirstDown) {
      final start = _downPositions[event.pointer];
      if (start != null &&
          (event.position - start).distance >
              computeHitSlop(event.kind, gestureSettings)) {
        resolve(GestureDisposition.accepted);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      // A pointer lifting before any claim is not ours: resolve rejected so
      // the arena sweep can hand the tap to fl_chart immediately.
      if (!_claimed) resolve(GestureDisposition.rejected);
      _downPositions.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (!_claimed) {
      _claimed = true;
      onClaimed?.call();
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    final wasClaimed = _claimed;
    _claimed = false;
    _downPositions.clear();
    if (wasClaimed) onReleased?.call();
  }

  @override
  String get debugDescription => 'chart touch claim';
}
