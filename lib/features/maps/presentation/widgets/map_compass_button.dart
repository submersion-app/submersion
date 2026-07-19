import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// A compass control that resets a rotated [FlutterMap] back to north.
///
/// `flutter_map` enables two-finger rotation by default but ships no visible
/// affordance to undo it, so a map that has been twisted stays crooked with no
/// way back (see issue #625). This control mirrors the Google/Apple Maps
/// convention: it stays hidden while the map is north-up, fades in as soon as
/// the map is rotated, points its needle at true north, and animates the
/// bearing back to zero when tapped.
///
/// Drop it into the [Stack] that hosts a [FlutterMap] (typically wrapped in a
/// [Positioned]) and pass the same [MapController] the map uses. It listens to
/// [MapController.mapEventStream], so the host page does not need to rebuild or
/// track rotation itself.
class MapCompassButton extends StatefulWidget {
  const MapCompassButton({
    super.key,
    required this.controller,
    this.resetDuration = const Duration(milliseconds: 300),
  });

  /// The controller of the [FlutterMap] this compass steers.
  final MapController controller;

  /// How long the animated glide back to north takes when tapped.
  final Duration resetDuration;

  @override
  State<MapCompassButton> createState() => _MapCompassButtonState();
}

class _MapCompassButtonState extends State<MapCompassButton>
    with SingleTickerProviderStateMixin {
  /// Rotations within this many degrees of north are treated as "north-up",
  /// hiding the control. Keeps floating-point drift from leaving it visible.
  static const double _hideThresholdDeg = 0.5;

  StreamSubscription<MapEvent>? _eventSub;
  late final AnimationController _resetController;

  /// Current map bearing in degrees, mirrored from map events.
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: widget.resetDuration,
    );
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant MapCompassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      // Abandon any reset in flight on the old controller before switching, so
      // its animation can never drive the newly swapped-in controller.
      _resetController.stop();
      _eventSub?.cancel();
      _subscribe();
    }
    _resetController.duration = widget.resetDuration;
  }

  /// Listen to the controller's events and seed [_rotation] from its current
  /// bearing. Seeding matters when the controller is already rotated as this
  /// widget mounts (or when a new controller is swapped in): without it the
  /// needle would show north until the next map event arrives.
  void _subscribe() {
    _eventSub = widget.controller.mapEventStream.listen(_onMapEvent);
    try {
      _rotation = widget.controller.camera.rotation;
    } on StateError {
      // The map is not attached to this controller yet; the first emitted
      // map event will sync the rotation.
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _resetController.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    final rotation = event.camera.rotation;
    if (rotation != _rotation && mounted) {
      setState(() => _rotation = rotation);
    }
  }

  /// Whether the map is currently (near enough to) north-up.
  bool get _isNorthUp {
    final normalized = _rotation % 360;
    final fromNorth = normalized < 0 ? normalized + 360 : normalized;
    return fromNorth < _hideThresholdDeg || fromNorth > 360 - _hideThresholdDeg;
  }

  Future<void> _resetToNorth() async {
    // Capture the controller this reset targets: if the widget is rebuilt with
    // a different controller mid-glide, the frames must keep driving the
    // original one, never the newly swapped-in controller.
    final controller = widget.controller;
    final start = _rotation;
    // Snap to the nearest multiple of 360 so the needle takes the shortest
    // path home (e.g. 350 degrees glides forward to 360, not back through 0).
    final end = (start / 360).roundToDouble() * 360;
    if (start == end) return;

    _resetController
      ..stop()
      ..reset();
    final animation = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeInOut,
    );
    void applyFrame() {
      if (!mounted) return;
      controller.rotate(start + (end - start) * animation.value);
    }

    animation.addListener(applyFrame);
    try {
      await _resetController.forward();
    } on TickerCanceled {
      // The widget was disposed mid-glide (e.g. the map was navigated away);
      // the reset is simply abandoned.
    } finally {
      animation.removeListener(applyFrame);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final northUp = _isNorthUp;

    // Exclude from the semantics tree while hidden: an invisible,
    // non-interactive button should not be reachable by screen readers.
    return ExcludeSemantics(
      excluding: northUp,
      child: IgnorePointer(
        ignoring: northUp,
        child: AnimatedOpacity(
          opacity: northUp ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: Tooltip(
            message: context.l10n.maps_compass_resetTooltip,
            child: Material(
              color: colorScheme.surface,
              elevation: 2,
              shape: CircleBorder(
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _resetToNorth,
                child: Semantics(
                  button: true,
                  label: context.l10n.maps_compass_resetLabel,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Transform.rotate(
                        angle: -_rotation * math.pi / 180,
                        child: CustomPaint(
                          size: const Size.square(22),
                          painter: _CompassNeedlePainter(
                            northColor: Colors.red.shade600,
                            southColor: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a two-tone compass needle: a colored north half and a muted south
/// half meeting at the center, so the pointing direction is unambiguous at any
/// rotation.
class _CompassNeedlePainter extends CustomPainter {
  _CompassNeedlePainter({required this.northColor, required this.southColor});

  final Color northColor;
  final Color southColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final halfWidth = size.width * 0.18;
    final top = size.height * 0.1;
    final bottom = size.height * 0.9;

    final north = Path()
      ..moveTo(cx, top)
      ..lineTo(cx - halfWidth, cy)
      ..lineTo(cx + halfWidth, cy)
      ..close();
    final south = Path()
      ..moveTo(cx, bottom)
      ..lineTo(cx - halfWidth, cy)
      ..lineTo(cx + halfWidth, cy)
      ..close();

    canvas
      ..drawPath(south, Paint()..color = southColor)
      ..drawPath(north, Paint()..color = northColor);
  }

  @override
  bool shouldRepaint(covariant _CompassNeedlePainter oldDelegate) =>
      oldDelegate.northColor != northColor ||
      oldDelegate.southColor != southColor;
}
