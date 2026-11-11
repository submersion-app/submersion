import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Hands vertical drags and wheel or trackpad scrolls that land on [child]
/// to the page's scroll view, as if they had landed on the page.
///
/// The pinned profile card and strip (issue #4423) lie over the dive details
/// page rather than inside its scroll view, so without this they would be a
/// dead zone for scrolling. Drags keep the page's own physics, fling
/// included; horizontal gestures inside [child] (scrubbing) are unaffected.
class PageScrollForwarder extends StatefulWidget {
  const PageScrollForwarder({
    super.key,
    required this.position,
    required this.child,
  });

  /// The page's scroll position, read when a gesture starts.
  final ScrollPosition? Function() position;
  final Widget child;

  @override
  State<PageScrollForwarder> createState() => _PageScrollForwarderState();
}

class _PageScrollForwarderState extends State<PageScrollForwarder> {
  Drag? _drag;

  void _onWheel(PointerSignalEvent event) {
    final position = widget.position();
    if (event is! PointerScrollEvent || position == null) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      position.pointerScroll((e as PointerScrollEvent).scrollDelta.dy);
    });
  }

  @override
  void dispose() {
    _drag?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onWheel,
      child: RawGestureDetector(
        gestures: {
          VerticalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                VerticalDragGestureRecognizer
              >(VerticalDragGestureRecognizer.new, (recognizer) {
                recognizer.onStart = (d) {
                  _drag = widget.position()?.drag(d, () => _drag = null);
                };
                recognizer.onUpdate = (d) => _drag?.update(d);
                recognizer.onEnd = (d) => _drag?.end(d);
                recognizer.onCancel = () => _drag?.cancel();
              }),
        },
        child: widget.child,
      ),
    );
  }
}
