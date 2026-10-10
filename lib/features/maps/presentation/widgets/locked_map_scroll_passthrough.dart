import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Wraps a locked map (`InteractiveFlag.none`) so a trackpad two-finger
/// scroll over it scrolls the enclosing page instead of going nowhere.
///
/// `flutter_map` registers its scale recognizer whatever the interaction
/// flags say, and that recognizer accepts trackpad pan-zoom. Over a locked
/// map it therefore wins the gesture arena from the page's scrollable and then
/// discards the gesture, so the page stops scrolling the moment a map slides
/// under the pointer (issue #3156). The mouse wheel and touch drags are not
/// affected: the wheel is a pointer signal the locked map ignores, and a touch
/// drag is won by the scrollable.
///
/// This claims only trackpad pan-zoom, eagerly, and forwards the movement to
/// the nearest [Scrollable]. Taps, mouse and touch input still reach the map
/// and the widgets inside it, such as a tappable pin or the attribution
/// button. Interactive maps use `TrackpadZoomMap` instead.
class LockedMapScrollPassthrough extends StatelessWidget {
  const LockedMapScrollPassthrough({super.key, required this.child});

  final Widget child;

  static void _scroll(BuildContext context, Offset panDelta) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    final direction = scrollable.axisDirection;
    // Fingers moving up scroll the content forward, the same sense as a touch
    // drag, so the pan delta is negated.
    var delta = axisDirectionToAxis(direction) == Axis.vertical
        ? -panDelta.dy
        : -panDelta.dx;
    if (axisDirectionIsReversed(direction)) delta = -delta;
    if (delta == 0) return;
    scrollable.position.pointerScroll(delta);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _TrackpadScrollRecognizer:
            GestureRecognizerFactoryWithHandlers<_TrackpadScrollRecognizer>(
              () => _TrackpadScrollRecognizer(debugOwner: this),
              (recognizer) =>
                  recognizer.onScroll = (delta) => _scroll(context, delta),
            ),
      },
      child: child,
    );
  }
}

/// Claims a trackpad pan-zoom gesture and reports each update's pan delta.
///
/// Like `TrackpadZoomGestureRecognizer`, [addAllowedPointer] is a no-op, so
/// ordinary pointers (mouse, touch, a trackpad click-drag) are left alone.
class _TrackpadScrollRecognizer extends OneSequenceGestureRecognizer {
  _TrackpadScrollRecognizer({super.debugOwner})
    : super(supportedDevices: const {PointerDeviceKind.trackpad});

  void Function(Offset panDelta)? onScroll;

  @override
  void addAllowedPointer(PointerDownEvent event) {}

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    super.addAllowedPointerPanZoom(event);
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerPanZoomUpdateEvent) {
      if (event.panDelta != Offset.zero) onScroll?.call(event.panDelta);
    } else if (event is PointerPanZoomEndEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'trackpadScroll';
}
