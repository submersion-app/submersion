import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Something on a map that a pointer drags, without the map panning under it.
///
/// A pan recognizer cannot do this. `flutter_map` teams drag recognizers that
/// accept after a touch slop with its scale recognizer, so the map claims the
/// gesture before a pan's larger slop is reached. A plain `Listener` claims
/// nothing, so both the target and the map follow the pointer. An eager
/// recognizer claims the pointer on press and the `Listener` reads it.
///
/// [onStart] and [onMove] take the pointer's global position.
class NavTrackMapDragTarget extends StatelessWidget {
  const NavTrackMapDragTarget({
    super.key,
    required this.onStart,
    required this.onMove,
    required this.child,
  });

  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onMove;
  final Widget child;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      EagerGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
            EagerGestureRecognizer.new,
            (_) {},
          ),
    },
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => onStart(event.position),
      onPointerMove: (event) => onMove(event.position),
      child: child,
    ),
  );
}
