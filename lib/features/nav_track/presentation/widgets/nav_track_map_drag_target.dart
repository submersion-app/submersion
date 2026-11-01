import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// The place on the ground under a pointer at [global], through [camera], so
/// it holds on a rotated map. [mapKey] is the map's own box, because a marker's
/// sits in the map's rotated layer space.
LatLng groundUnderPointer(GlobalKey mapKey, MapCamera camera, Offset global) {
  final box = mapKey.currentContext!.findRenderObject()! as RenderBox;
  return camera.screenOffsetToLatLng(box.globalToLocal(global));
}

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
