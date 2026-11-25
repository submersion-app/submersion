import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Hands a drag that runs past either end of a small nested list on to the
/// vertical scrollable around it, as a drag of that scrollable's own: it
/// follows the finger, keeps the flick when the finger lifts, and is refused
/// where that scrollable's physics refuse a user's drag.
///
/// Feed it the nested list's [ScrollNotification]s with [handle]; [cancel]
/// when the list goes away.
class OverscrollHandoff {
  Drag? _drag;

  /// Acts on [notification] from the nested list. [context] is above the
  /// list and below the scrollable that should take the drag.
  void handle(ScrollNotification notification, BuildContext context) {
    // Only the list's own notifications, not those of anything nested in it.
    if (notification.depth != 0) return;
    if (notification case OverscrollNotification(
      :final dragDetails?,
      :final overscroll,
    )) {
      final drag = _drag ?? _start(dragDetails, context);
      // Only the part the list could not take, in the finger's terms.
      drag?.update(
        DragUpdateDetails(
          globalPosition: dragDetails.globalPosition,
          localPosition: dragDetails.localPosition,
          sourceTimeStamp: dragDetails.sourceTimeStamp,
          delta: Offset(0, -overscroll),
          primaryDelta: -overscroll,
        ),
      );
    } else if (notification case ScrollEndNotification(
      :final dragDetails,
      :final metrics,
    ) when _drag != null) {
      final drag = _drag!;
      _drag = null;
      // The flick goes on only when the finger lifts still pushing past
      // the list's end; once it turned back, the list took it.
      drag.end(
        dragDetails != null && metrics.atEdge
            ? dragDetails
            : DragEndDetails(primaryVelocity: 0),
      );
    }
  }

  Drag? _start(DragUpdateDetails details, BuildContext context) {
    final outer = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (outer == null || !outer.physics.shouldAcceptUserOffset(outer)) {
      return null;
    }
    return _drag = outer.drag(
      DragStartDetails(
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
        sourceTimeStamp: details.sourceTimeStamp,
      ),
      () => _drag = null,
    );
  }

  /// Lets go of a drag still being handed on, without a flick.
  void cancel() {
    final drag = _drag;
    _drag = null;
    drag?.cancel();
  }
}
