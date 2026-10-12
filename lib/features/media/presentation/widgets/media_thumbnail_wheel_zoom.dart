import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';

/// Whether the key that turns the wheel into a size control is down: Ctrl,
/// or Cmd on macOS, which keeps Ctrl + scroll for its own accessibility
/// screen zoom.
bool _zoomModifierPressed() {
  final keyboard = HardwareKeyboard.instance;
  return defaultTargetPlatform == TargetPlatform.macOS
      ? keyboard.isMetaPressed
      : keyboard.isControlPressed;
}

/// Resizes the library's thumbnails from the mouse wheel (issue #3297):
/// with the modifier held, each click of the wheel moves the size one
/// slider stop, up for larger and down for smaller.
///
/// The scroll views under [child] must use [MediaThumbnailWheelZoomPhysics],
/// or they take the wheel for themselves as soon as they have anything to
/// scroll.
class MediaThumbnailWheelZoom extends ConsumerWidget {
  const MediaThumbnailWheelZoom({super.key, required this.child});

  final Widget child;

  void _onPointerSignal(WidgetRef ref, PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0 || !_zoomModifierPressed()) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      // One stop per event, whatever distance it reports: a wheel sends one
      // event per click, and the distance varies by platform and mouse.
      ref.read(mediaThumbnailScaleProvider.notifier).stepBy(dy < 0 ? 1 : -1);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Listener(
      onPointerSignal: (event) => _onPointerSignal(ref, event),
      child: child,
    );
  }
}

/// Scroll physics for the library's thumbnail views: as the default for a
/// page's main scroll view, except that user scrolling is refused while the
/// zoom modifier is down.
///
/// A scroll view claims a wheel event before any widget above it can, and
/// the first claim wins, so the only way to keep the wheel from scrolling
/// is for the scroll view itself to decline. It asks its physics on every
/// event, which is where this answers.
///
/// Set on the scroll view itself, not through a ScrollConfiguration: a
/// vertical scroll view with no controller defaults to
/// [AlwaysScrollableScrollPhysics], which accepts the wheel whatever the
/// ambient physics say. That is why this wraps one, and why inheriting it
/// worked only until the content outgrew the pane.
class MediaThumbnailWheelZoomPhysics extends ScrollPhysics {
  const MediaThumbnailWheelZoomPhysics({
    super.parent = const AlwaysScrollableScrollPhysics(),
  });

  @override
  MediaThumbnailWheelZoomPhysics applyTo(ScrollPhysics? ancestor) =>
      MediaThumbnailWheelZoomPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      !_zoomModifierPressed() && super.shouldAcceptUserOffset(position);
}
