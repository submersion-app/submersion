import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';

/// Draggable host for [PerdixFace]. In video mode ([playback] non-null) the
/// face re-resolves on every playback tick via an [AnimatedBuilder], so only
/// this subtree rebuilds per frame; in photo mode it renders one static
/// sample at [baseElapsedSeconds].
///
/// Drag mechanics mirror [DraggableReadoutCard]: the position is a fraction
/// of the movable range (stack area minus a 12 px inset, minus the face
/// size); (0,0) is the inset top-left corner, (1,1) the inset bottom-right.
/// Must be placed directly inside a [Stack].
class DraggablePerdixOverlay extends StatefulWidget {
  const DraggablePerdixOverlay({
    super.key,
    required this.resolver,
    required this.baseElapsedSeconds,
    required this.settings,
    this.playback,
    this.positionGetter,
    this.initialFraction,
    this.onDragEnd,
    this.topReserve = 0,
  }) : assert(
         playback == null || positionGetter != null,
         'positionGetter is required in video mode',
       );

  /// Resolves face data for a dive-time second; built by the page from the
  /// dive's profile/analysis/tanks.
  final PerdixFaceResolver resolver;

  /// Seconds into the dive at the media item's capture start
  /// (enrichment.elapsedSeconds).
  final int baseElapsedSeconds;

  final AppSettings settings;

  /// Ticks with video playback (a VideoPlayerController works directly);
  /// null renders the static photo mode.
  final Listenable? playback;

  /// Current playback position; required when [playback] is non-null.
  final Duration Function()? positionGetter;

  /// Starting position fraction; null uses [defaultFraction].
  final Offset? initialFraction;

  /// Called with the final position fraction when a drag ends; the caller
  /// persists it in settings.
  final ValueChanged<Offset>? onDragEnd;

  /// Height at the top of the stack the face is kept out of, on top of the
  /// standard inset. The viewer passes its top toolbar's height: the toolbar
  /// is the only chrome with buttons, and a face parked underneath them both
  /// shadows the buttons and loses the pointers that would drag it back out.
  final double topReserve;

  /// Default position: top-right corner.
  static const Offset defaultFraction = Offset(1, 0);

  @override
  State<DraggablePerdixOverlay> createState() => _DraggablePerdixOverlayState();
}

/// Pan recognizer that claims the pointer the moment it lands on the face,
/// rather than waiting for the pan slop to be exceeded.
///
/// The photo viewer wraps its whole Stack in a swipe-down-to-close
/// [VerticalDragGestureRecognizer], which is an ancestor of the face and so
/// contends for every drag that starts on it -- being painted above the chrome
/// does not help. That recognizer accepts at `kTouchSlop` while a plain
/// [PanGestureRecognizer] holds out for the larger `kPanSlop`, so it won every
/// downward drag: pulling the face out of its corner either did nothing or
/// dismissed the viewer. Winning the arena on pointer-down keeps drags that
/// begin on the face for the face. Taps on it already do nothing, and
/// swipe-to-close still works everywhere outside it.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _DraggablePerdixOverlayState extends State<DraggablePerdixOverlay> {
  static const _inset = 12.0;

  final GlobalKey _faceKey = GlobalKey();
  late Offset _fraction = _sanitize(
    widget.initialFraction ?? DraggablePerdixOverlay.defaultFraction,
  );

  /// Same contract as DraggableReadoutCard: persisted values are not
  /// guaranteed in-range, and the Stack clips, so out-of-range or non-finite
  /// fractions must never strand the face off-screen.
  static Offset _sanitize(Offset fraction) => Offset(
    fraction.dx.isFinite
        ? fraction.dx.clamp(0.0, 1.0)
        : DraggablePerdixOverlay.defaultFraction.dx,
    fraction.dy.isFinite
        ? fraction.dy.clamp(0.0, 1.0)
        : DraggablePerdixOverlay.defaultFraction.dy,
  );

  /// Position when the current gesture started, or null outside a gesture.
  /// The recognizer claims the pointer on contact, so a plain tap produces a
  /// start/end pair too, and dragging further into an edge the fraction is
  /// already clamped against produces updates that change nothing. Comparing
  /// against this covers both: only a net move reaches [onDragEnd], instead of
  /// persisting an unchanged position and bouncing the settings provider (and
  /// the page) for nothing.
  Offset? _dragStartFraction;

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final faceSize = _faceKey.currentContext?.size;
    if (faceSize == null) return;
    final movableW = constraints.maxWidth - faceSize.width;
    final movableH = constraints.maxHeight - faceSize.height;
    final next = Offset(
      movableW <= 0
          ? 0
          : (_fraction.dx + details.delta.dx / movableW).clamp(0.0, 1.0),
      movableH <= 0
          ? 0
          : (_fraction.dy + details.delta.dy / movableH).clamp(0.0, 1.0),
    );
    // A drag pushing past an edge repeats the clamped value every frame; not
    // rebuilding for those keeps the face's per-frame video rebuild the only
    // work happening during playback.
    if (next == _fraction) return;
    setState(() => _fraction = next);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _inset,
          _inset + widget.topReserve,
          _inset,
          _inset,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: FractionalOffset(_fraction.dx, _fraction.dy),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: RawGestureDetector(
                // Sized by its child: measuring this context yields the face
                // size for the fraction math in _onPanUpdate.
                key: _faceKey,
                // Opaque rather than deferToChild so the grab surface is the
                // panel's bounds, independent of which parts of the readout
                // happen to hit-test.
                behavior: HitTestBehavior.opaque,
                gestures: {
                  _EagerPanGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _EagerPanGestureRecognizer
                      >(_EagerPanGestureRecognizer.new, (recognizer) {
                        recognizer.onStart = (_) {
                          _dragStartFraction = _fraction;
                        };
                        recognizer.onUpdate = (details) {
                          _onPanUpdate(details, constraints);
                        };
                        recognizer.onEnd = (_) {
                          if (_fraction != _dragStartFraction) {
                            widget.onDragEnd?.call(_fraction);
                          }
                          _dragStartFraction = null;
                        };
                      }),
                },
                child: _buildFace(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFace() {
    final playback = widget.playback;
    if (playback == null) {
      return PerdixFace(
        data: widget.resolver.resolve(widget.baseElapsedSeconds),
        settings: widget.settings,
        showDragHandle: true,
      );
    }
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final position = widget.positionGetter!();
        final t = widget.baseElapsedSeconds + position.inMilliseconds ~/ 1000;
        return PerdixFace(
          data: widget.resolver.resolve(t),
          settings: widget.settings,
          showDragHandle: true,
        );
      },
    );
  }
}
