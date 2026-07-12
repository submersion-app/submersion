import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

/// How the scrub cursor is drawn: a dot riding the path (depth/tissue/career/
/// spatial scenes), or a vertical time-plane sweeping every ribbon at once
/// (the comparison scene).
enum ScrubCursorStyle { dot, timePlane }

/// Interactive 3D viewport rendered entirely with CustomPaint: the scene
/// paints via [Dive3dScenePainter] (Canvas.drawVertices, GPU-rasterized by
/// Flutter itself) and gestures drive the orthographic camera. No external
/// 3D engine. The scrub cursor lives in a foregroundPainter that follows
/// the scene's ScrubPath and listens to the frame-rate ValueListenable, so
/// playback repaints only the cursor layer, never re-sorts the scene.
class Dive3dInteractiveViewport extends StatefulWidget {
  final Scene3d scene;
  final ValueListenable<double> scrubPosition;
  final Set<SceneOverlay> visibleOverlays;
  final void Function(SceneMarker marker)? onMarkerTap;
  final ScrubCursorStyle scrubCursor;

  const Dive3dInteractiveViewport({
    super.key,
    required this.scene,
    required this.scrubPosition,
    required this.visibleOverlays,
    this.onMarkerTap,
    this.scrubCursor = ScrubCursorStyle.dot,
  });

  @override
  State<Dive3dInteractiveViewport> createState() =>
      _Dive3dInteractiveViewportState();
}

class _Dive3dInteractiveViewportState extends State<Dive3dInteractiveViewport> {
  static const double _initialYaw = -32;
  static const double _initialPitch = 22;
  double _yaw = _initialYaw;
  double _pitch = _initialPitch;
  double _zoom = 1.0;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _yaw -= details.delta.dx * 0.4;
      _pitch = (_pitch + details.delta.dy * 0.4).clamp(-80.0, 80.0);
    });
  }

  void _zoomBy(double factor) {
    setState(() {
      _zoom = (_zoom * factor).clamp(0.4, 8.0);
    });
  }

  void _resetCamera() {
    setState(() {
      _yaw = _initialYaw;
      _pitch = _initialPitch;
      _zoom = 1.0;
    });
  }

  SceneProjector _projectorFor(Size size) => SceneProjector(
    size: size,
    bounds: widget.scene.bounds,
    yawDegrees: _yaw,
    pitchDegrees: _pitch,
    zoom: _zoom,
  );

  void _handleTapUp(Size size, TapUpDetails details) {
    final onTap = widget.onMarkerTap;
    if (onTap == null ||
        !widget.visibleOverlays.contains(SceneOverlay.markers)) {
      return;
    }
    final projector = _projectorFor(size);
    SceneMarker? best;
    var bestDistance = 24.0;
    for (final marker in widget.scene.markers) {
      final d =
          (projector.project(marker.x, marker.y, 0) - details.localPosition)
              .distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = marker;
      }
    }
    if (best != null) onTap(best);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _zoomBy(signal.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
            }
          },
          child: GestureDetector(
            onPanUpdate: _onPanUpdate,
            onDoubleTap: _resetCamera,
            onTapUp: (details) => _handleTapUp(size, details),
            child: CustomPaint(
              painter: Dive3dScenePainter(
                scene: widget.scene,
                yawDegrees: _yaw,
                pitchDegrees: _pitch,
                zoom: _zoom,
                visibleOverlays: widget.visibleOverlays,
              ),
              foregroundPainter: _ScrubCursorPainter(
                scene: widget.scene,
                yawDegrees: _yaw,
                pitchDegrees: _pitch,
                zoom: _zoom,
                scrubPosition: widget.scrubPosition,
                style: widget.scrubCursor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

/// Foreground layer: only the scrub cursor. Repaints on every scrub tick
/// (via [scrubPosition] as the repaint listenable) without touching the
/// depth-sorted scene beneath it. Placed via the scene's ScrubPath.
class _ScrubCursorPainter extends CustomPainter {
  final Scene3d scene;
  final double yawDegrees;
  final double pitchDegrees;
  final double zoom;
  final ValueListenable<double> scrubPosition;
  final ScrubCursorStyle style;

  _ScrubCursorPainter({
    required this.scene,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.zoom,
    required this.scrubPosition,
    required this.style,
  }) : super(repaint: scrubPosition);

  @override
  void paint(Canvas canvas, Size size) {
    final path = scene.scrubPath;
    if (path == null) return;
    final scenePoint = path.sceneAt(scrubPosition.value);
    if (scenePoint == null) return;
    final projector = SceneProjector(
      size: size,
      bounds: scene.bounds,
      yawDegrees: yawDegrees,
      pitchDegrees: pitchDegrees,
      zoom: zoom,
    );
    if (style == ScrubCursorStyle.timePlane) {
      final b = scene.bounds;
      final corners = <Offset>[
        projector.project(scenePoint.x, b.sceneMaxY, b.sceneMinZ),
        projector.project(scenePoint.x, b.sceneMaxY, b.sceneMaxZ),
        projector.project(scenePoint.x, b.sceneMinY, b.sceneMaxZ),
        projector.project(scenePoint.x, b.sceneMinY, b.sceneMinZ),
      ];
      final plane = Path()..addPolygon(corners, true);
      canvas.drawPath(
        plane,
        Paint()..color = Colors.white.withValues(alpha: 0.10),
      );
      canvas.drawPath(
        plane,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
    final center = projector.project(scenePoint.x, scenePoint.y, scenePoint.z);
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrubCursorPainter oldDelegate) =>
      !identical(oldDelegate.scene, scene) ||
      oldDelegate.yawDegrees != yawDegrees ||
      oldDelegate.pitchDegrees != pitchDegrees ||
      oldDelegate.zoom != zoom ||
      oldDelegate.style != style;
}
