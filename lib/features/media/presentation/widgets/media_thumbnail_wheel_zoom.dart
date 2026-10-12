import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_zoom_anchor.dart';

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
///
/// The thumbnail under the cursor is noted as the size changes and offered
/// to those views through [MediaThumbnailZoomAnchorScope], so they can keep
/// it on the cursor's line.
class MediaThumbnailWheelZoom extends ConsumerStatefulWidget {
  const MediaThumbnailWheelZoom({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MediaThumbnailWheelZoom> createState() =>
      _MediaThumbnailWheelZoomState();
}

class _MediaThumbnailWheelZoomState
    extends ConsumerState<MediaThumbnailWheelZoom> {
  final _anchor = MediaThumbnailZoomAnchorHolder();

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // A wheel only. A trackpad's scroll is a stream of small events, not
    // clicks, and one stop per event would race through every size.
    if (event.kind == PointerDeviceKind.trackpad) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0 || !_zoomModifierPressed()) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!mounted) return;
      final notifier = ref.read(mediaThumbnailScaleProvider.notifier);
      final before = ref.read(mediaThumbnailScaleProvider).step;
      // One stop per event, whatever distance it reports: a wheel sends one
      // event per click, and the distance varies by platform and mouse.
      notifier.stepBy(dy < 0 ? 1 : -1);
      if (ref.read(mediaThumbnailScaleProvider).step == before) return;
      final box = context.findRenderObject();
      if (box is! RenderBox) return;
      _anchor.capture(event.position, box);
      // Only for the rebuild this step causes: a step that changes nothing
      // on screen must not leave an anchor for the slider to trip over.
      WidgetsBinding.instance.addPostFrameCallback((_) => _anchor.clear());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: MediaThumbnailZoomAnchorScope(
        holder: _anchor,
        child: widget.child,
      ),
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
/// The same question is also asked at layout, where the answer decides
/// whether the view can be dragged at all until it is next laid out. A
/// zoom relays the view out while the modifier is still down, so the key
/// must only count when a pointer event asks, or a trackpad's two-finger
/// scroll, which arrives as a drag, would stay off once the key is up.
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
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    final accepts = super.shouldAcceptUserOffset(position);
    final atLayout =
        SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
    return accepts && (atLayout || !_zoomModifierPressed());
  }

  /// A zoom moves the offset before the new layout exists, so it can ask
  /// for a place past the end of what the gallery turns out to hold. At
  /// rest, the offset is brought back inside as the new extent arrives,
  /// in the same frame and with no spring.
  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final adjusted = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    if (isScrolling) return adjusted;
    return adjusted.clamp(
      newPosition.minScrollExtent,
      newPosition.maxScrollExtent,
    );
  }
}
