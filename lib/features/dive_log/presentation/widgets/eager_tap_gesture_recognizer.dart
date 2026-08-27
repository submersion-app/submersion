import 'package:flutter/gestures.dart';

/// A tap that wins its gesture arena the instant the pointer lifts.
///
/// Overlays using this render inside the chart's [GestureDetector], which
/// handles double-tap-to-zoom. Flutter's [DoubleTapGestureRecognizer] holds
/// the pointer's arena for [kDoubleTapTimeout] (300ms) after the first tap
/// up, and a plain [TapGestureRecognizer] never self-accepts - it waits for
/// the arena sweep that the hold defers. So an ordinary
/// [GestureDetector.onTap] here lags 300ms behind the finger, and an
/// impatient second tap lands inside the double-tap window, zooming the
/// chart instead of acting on the marker. Resolving accepted on the up event
/// ends the hold immediately.
///
/// Drags are unaffected: [PrimaryPointerGestureRecognizer] rejects this
/// recognizer as soon as the pointer travels past `kTouchSlop`, so a pan
/// that starts on a marker still pans the chart.
class EagerTapGestureRecognizer extends TapGestureRecognizer {
  EagerTapGestureRecognizer({super.debugOwner});

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (event is PointerUpEvent) {
      resolve(GestureDisposition.accepted);
    }
    super.handlePrimaryPointer(event);
  }
}
