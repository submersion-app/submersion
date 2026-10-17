part of 'dive_3d_interactive_viewport.dart';

/// A scale recognizer that ignores trackpad pan/zoom pointers.
///
/// `supportedDevices` filters pointer-DOWN events only:
/// [GestureRecognizer.isPointerPanZoomAllowed] returns true unconditionally,
/// so a trackpad gesture reaches every recognizer no matter what devices it
/// declares. The viewport handles trackpads on a [Listener], and without this
/// refusal both paths would fire and every trackpad pan would move the camera
/// twice.
class _TouchScaleGestureRecognizer extends ScaleGestureRecognizer {
  _TouchScaleGestureRecognizer({super.supportedDevices});

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;
}

/// Claims trackpad pan/zoom pointers for the viewport in the gesture arena,
/// and does nothing else with them: the viewport's [Listener] moves the
/// camera. Without a claim, a scrolling ancestor (the Site Details page)
/// wins the arena uncontested, and one two-finger swipe over the viewport
/// both scrolls the page and pans the camera.
class _TrackpadPanZoomClaim extends OneSequenceGestureRecognizer {
  @override
  bool isPointerAllowed(PointerDownEvent event) => false;

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerPanZoomEndEvent) stopTrackingPointer(event.pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'trackpad pan-zoom claim';
}
