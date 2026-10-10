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
/// This claims only trackpad pan-zoom, eagerly, and drives it as a drag on
/// the nearest [Scrollable] along the gesture's main axis, the way the
/// scrollable's own drag recognizer would: the page tracks the fingers and
/// keeps its fling after they lift. Taps, mouse and touch input still reach the
/// map and the widgets inside it, such as a tappable pin or the attribution
/// button. Interactive maps use `TrackpadZoomMap` instead.
class LockedMapScrollPassthrough extends StatefulWidget {
  const LockedMapScrollPassthrough({super.key, required this.child});

  final Widget child;

  @override
  State<LockedMapScrollPassthrough> createState() =>
      _LockedMapScrollPassthroughState();
}

class _LockedMapScrollPassthroughState
    extends State<LockedMapScrollPassthrough> {
  Drag? _drag;
  Axis _axis = Axis.vertical;

  /// Starts the drag on the first movement, once the gesture's main axis is
  /// known, so a vertical scroll skips a nearer horizontal scrollable.
  void _update(Offset panDelta, Offset globalPosition) {
    // The recognizer reports only non-zero movement.
    if (_drag == null) {
      final axis = panDelta.dy.abs() >= panDelta.dx.abs()
          ? Axis.vertical
          : Axis.horizontal;
      final position = Scrollable.maybeOf(context, axis: axis)?.position;
      // The same gate the scrollable applies to its own user scrolling.
      if (position == null ||
          !position.physics.shouldAcceptUserOffset(position)) {
        return;
      }
      _axis = axis;
      _drag = position.drag(
        DragStartDetails(
          globalPosition: globalPosition,
          kind: PointerDeviceKind.trackpad,
        ),
        () => _drag = null,
      );
    }
    // The drag controller takes the finger's movement and handles the axis
    // direction itself; trackpad pan already moves in the touch-drag sense.
    final primary = _axis == Axis.vertical ? panDelta.dy : panDelta.dx;
    _drag?.update(
      DragUpdateDetails(
        globalPosition: globalPosition,
        delta: _axis == Axis.vertical ? Offset(0, primary) : Offset(primary, 0),
        primaryDelta: primary,
      ),
    );
  }

  void _end(Velocity velocity) {
    final primary = _axis == Axis.vertical
        ? velocity.pixelsPerSecond.dy
        : velocity.pixelsPerSecond.dx;
    _drag?.end(
      DragEndDetails(
        velocity: Velocity(
          pixelsPerSecond: _axis == Axis.vertical
              ? Offset(0, primary)
              : Offset(primary, 0),
        ),
        primaryVelocity: primary,
      ),
    );
    _drag = null;
  }

  @override
  void dispose() {
    _drag?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _TrackpadScrollRecognizer:
            GestureRecognizerFactoryWithHandlers<_TrackpadScrollRecognizer>(
              () => _TrackpadScrollRecognizer(debugOwner: this),
              (recognizer) => recognizer
                ..onUpdate = _update
                ..onEnd = _end,
            ),
      },
      child: widget.child,
    );
  }
}

/// Claims a trackpad pan-zoom gesture, reporting each update's pan delta and
/// the release velocity.
///
/// Like `TrackpadZoomGestureRecognizer`, it takes only pan-zoom: ordinary
/// pointers (mouse, touch, a trackpad click-drag) are never added, since the
/// inherited `addAllowedPointer` ignores them.
class _TrackpadScrollRecognizer extends OneSequenceGestureRecognizer {
  _TrackpadScrollRecognizer({super.debugOwner})
    : super(supportedDevices: const {PointerDeviceKind.trackpad});

  void Function(Offset panDelta, Offset globalPosition)? onUpdate;
  void Function(Velocity velocity)? onEnd;

  VelocityTracker? _tracker;

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    super.addAllowedPointerPanZoom(event);
    _tracker = VelocityTracker.withKind(PointerDeviceKind.trackpad);
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerPanZoomUpdateEvent) {
      _tracker?.addPosition(event.timeStamp, event.pan);
      if (event.panDelta != Offset.zero) {
        onUpdate?.call(event.panDelta, event.position);
      }
    } else if (event is PointerPanZoomEndEvent) {
      onEnd?.call(_tracker?.getVelocity() ?? Velocity.zero);
      _tracker = null;
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'trackpadScroll';
}
