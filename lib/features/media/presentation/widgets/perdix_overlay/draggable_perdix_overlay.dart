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

  /// Default position: top-right corner.
  static const Offset defaultFraction = Offset(1, 0);

  @override
  State<DraggablePerdixOverlay> createState() => _DraggablePerdixOverlayState();
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

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final faceSize = _faceKey.currentContext?.size;
    if (faceSize == null) return;
    final movableW = constraints.maxWidth - faceSize.width;
    final movableH = constraints.maxHeight - faceSize.height;
    setState(() {
      _fraction = Offset(
        movableW <= 0
            ? 0
            : (_fraction.dx + details.delta.dx / movableW).clamp(0.0, 1.0),
        movableH <= 0
            ? 0
            : (_fraction.dy + details.delta.dy / movableH).clamp(0.0, 1.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: FractionalOffset(_fraction.dx, _fraction.dy),
            child: GestureDetector(
              // Sized by its child: measuring this context yields the face
              // size for the fraction math in _onPanUpdate.
              key: _faceKey,
              onPanUpdate: (details) => _onPanUpdate(details, constraints),
              onPanEnd: (_) => widget.onDragEnd?.call(_fraction),
              child: _buildFace(),
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
        );
      },
    );
  }
}
