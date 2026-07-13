import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scrub_cursor.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

  /// Tissue-only chrome. All null for the dive/computers scenes, in which case
  /// the viewport behaves exactly as before (no axes/grid/tooltip picking).
  final TissueSurfaceGrid? surfaceGrid;
  final AxisFrame? axisFrame;
  final AxisLabelSet? axisLabels;
  final TissueChromeStyle? chromeStyle;
  final ValueNotifier<TissuePick?>? hoverPick;

  const Dive3dInteractiveViewport({
    super.key,
    required this.scene,
    required this.scrubPosition,
    required this.visibleOverlays,
    this.onMarkerTap,
    this.scrubCursor = ScrubCursorStyle.dot,
    this.surfaceGrid,
    this.axisFrame,
    this.axisLabels,
    this.chromeStyle,
    this.hoverPick,
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
  // Screen-space translation from panning (two-finger trackpad drag). Applied
  // as a Transform on the painted output; picks subtract it from the cursor.
  Offset _pan = Offset.zero;
  double _panZoomBaseZoom = 1.0;
  // Last laid-out size, captured in build so camera-change handlers (which lack
  // the LayoutBuilder constraints) can re-project the hover pick.
  Size? _lastLayoutSize;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // Drag follows the object: dragging right spins it clockwise (yaw up),
      // dragging down tilts it toward the viewer.
      _yaw += details.delta.dx * 0.4;
      _pitch = (_pitch + details.delta.dy * 0.4).clamp(-80.0, 80.0);
    });
    _refreshHoverAfterCameraChange();
  }

  void _zoomBy(double factor) {
    setState(() {
      _zoom = (_zoom * factor).clamp(0.4, 8.0);
    });
    _refreshHoverAfterCameraChange();
  }

  // Trackpad two-finger pan + pinch-zoom (desktop). Rotation via one-finger
  // drag stays on the pan gesture; the mouse wheel stays on pointer signals.
  void _onPanZoomStart(PointerPanZoomStartEvent _) {
    _panZoomBaseZoom = _zoom;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    setState(() {
      _pan += event.panDelta;
      _zoom = (_panZoomBaseZoom * event.scale).clamp(0.4, 8.0);
    });
    _refreshHoverAfterCameraChange();
  }

  void _resetCamera() {
    setState(() {
      _yaw = _initialYaw;
      _pitch = _initialPitch;
      _zoom = 1.0;
      _pan = Offset.zero;
    });
    _refreshHoverAfterCameraChange();
  }

  // The marker ring re-projects the hovered vertex from its (col, comp) every
  // paint, so it tracks the camera. The tooltip overlay lives outside the paint
  // transform and is placed from the pick's cached screenPos, so a camera change
  // with a stationary cursor (wheel/button zoom, trackpad pan-pinch, rotate)
  // would strand it. Re-derive screenPos for the current camera so both stay
  // locked to the vertex.
  void _refreshHoverAfterCameraChange() {
    final size = _lastLayoutSize;
    final notifier = widget.hoverPick;
    final grid = widget.surfaceGrid;
    final pick = notifier?.value;
    if (size == null ||
        notifier == null ||
        grid == null ||
        grid.isEmpty ||
        pick == null) {
      return;
    }
    if (pick.col >= grid.columns || pick.comp >= grid.compartments) {
      notifier.value = null; // pick went stale against a smaller grid
      return;
    }
    // Only the picked vertex needs re-projecting -- reprojecting the whole grid
    // (220x16) every drag/zoom tick is wasted work here; the marker ring and the
    // next real pick reproject the full grid independently when they need it.
    final (x, y, z) = grid.positionAt(pick.col, pick.comp);
    notifier.value = TissuePick(
      col: pick.col,
      comp: pick.comp,
      screenPos: _projectorFor(size).project(x, y, z) + _pan,
    );
  }

  SceneProjector _projectorFor(Size size) => SceneProjector(
    size: size,
    bounds: widget.scene.bounds,
    yawDegrees: _yaw,
    pitchDegrees: _pitch,
    zoom: _zoom,
  );

  // Cached screen projections of the surface grid, recomputed when the camera,
  // size, OR the grid itself changes (a new surface reuses stale projections
  // otherwise, so hover picks would point at the wrong vertex).
  List<Offset>? _projected;
  List<double>? _viewDepths;
  double? _cacheYaw, _cachePitch, _cacheZoom;
  Size? _cacheSize;
  TissueSurfaceGrid? _cacheGrid;

  void _ensureProjection(Size size) {
    final grid = widget.surfaceGrid;
    if (grid == null || grid.isEmpty) {
      _projected = null;
      _viewDepths = null;
      _cacheGrid = null;
      return;
    }
    if (_projected != null &&
        identical(_cacheGrid, grid) &&
        _cacheYaw == _yaw &&
        _cachePitch == _pitch &&
        _cacheZoom == _zoom &&
        _cacheSize == size) {
      return;
    }
    final p = _projectorFor(size);
    final n = grid.columns * grid.compartments;
    final proj = List<Offset>.filled(n, Offset.zero);
    final depths = List<double>.filled(n, 0);
    for (var col = 0; col < grid.columns; col++) {
      for (var comp = 0; comp < grid.compartments; comp++) {
        final (x, y, z) = grid.positionAt(col, comp);
        final i = col * grid.compartments + comp;
        proj[i] = p.project(x, y, z);
        depths[i] = p.viewDepth(x, y, z);
      }
    }
    _projected = proj;
    _viewDepths = depths;
    _cacheGrid = grid;
    _cacheYaw = _yaw;
    _cachePitch = _pitch;
    _cacheZoom = _zoom;
    _cacheSize = size;
  }

  void _pickAt(Size size, Offset local) {
    final notifier = widget.hoverPick;
    final grid = widget.surfaceGrid;
    if (notifier == null || grid == null || grid.isEmpty) return;
    _ensureProjection(size);
    final pick = pickNearestTissueVertex(
      // Projections are computed without pan; the painted output is translated
      // by _pan, so map the cursor back into untranslated projection space.
      cursor: local - _pan,
      projected: _projected!,
      viewDepths: _viewDepths!,
      columns: grid.columns,
      compartments: grid.compartments,
    );
    // Republish screenPos in viewport-local (painted) space so the tooltip
    // overlay -- which lives OUTSIDE the pan Transform -- sits on the vertex.
    notifier.value = pick == null
        ? null
        : TissuePick(
            col: pick.col,
            comp: pick.comp,
            screenPos: pick.screenPos + _pan,
          );
  }

  void _handleTapUp(Size size, TapUpDetails details) {
    final onTap = widget.onMarkerTap;
    if (onTap == null ||
        !widget.visibleOverlays.contains(SceneOverlay.markers)) {
      return;
    }
    final projector = _projectorFor(size);
    final cursor = details.localPosition - _pan; // undo pan translation
    SceneMarker? best;
    var bestDistance = 24.0;
    for (final marker in widget.scene.markers) {
      final d = (projector.project(marker.x, marker.y, 0) - cursor).distance;
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
        _lastLayoutSize = size;
        final hasChrome =
            widget.surfaceGrid != null &&
            widget.axisFrame != null &&
            widget.chromeStyle != null &&
            widget.hoverPick != null;

        final scenePaint = CustomPaint(
          painter: Dive3dScenePainter(
            scene: widget.scene,
            yawDegrees: _yaw,
            pitchDegrees: _pitch,
            zoom: _zoom,
            visibleOverlays: widget.visibleOverlays,
          ),
          foregroundPainter: hasChrome
              ? TissueChromePainter(
                  scene: widget.scene,
                  grid: widget.surfaceGrid!,
                  frame: widget.axisFrame!,
                  style: widget.chromeStyle!,
                  yawDegrees: _yaw,
                  pitchDegrees: _pitch,
                  zoom: _zoom,
                  scrubPosition: widget.scrubPosition,
                  hoverPick: widget.hoverPick!,
                  labels: widget.axisLabels,
                  textDirection: Directionality.of(context),
                )
              : _ScrubCursorPainter(
                  scene: widget.scene,
                  yawDegrees: _yaw,
                  pitchDegrees: _pitch,
                  zoom: _zoom,
                  scrubPosition: widget.scrubPosition,
                  style: widget.scrubCursor,
                ),
          child: const SizedBox.expand(),
        );

        // Frame grid draws behind the surface (paint order gives occlusion).
        final painted = hasChrome
            ? CustomPaint(
                painter: TissueFramePainter(
                  bounds: widget.scene.bounds,
                  frame: widget.axisFrame!,
                  style: widget.chromeStyle!,
                  yawDegrees: _yaw,
                  pitchDegrees: _pitch,
                  zoom: _zoom,
                ),
                child: scenePaint,
              )
            : scenePaint;

        final gestures = RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            // Rotate: one-finger drag from mouse/touch/stylus. Trackpad
            // two-finger pans are handled as pan by the Listener below, so we
            // exclude trackpad here to avoid rotating while panning.
            PanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                  () => PanGestureRecognizer(
                    supportedDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.invertedStylus,
                      PointerDeviceKind.unknown,
                    },
                  ),
                  (r) => r.onUpdate = _onPanUpdate,
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (r) => r.onTapUp = (details) {
                    _handleTapUp(size, details);
                    _pickAt(size, details.localPosition);
                  },
                ),
            DoubleTapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  DoubleTapGestureRecognizer
                >(
                  () => DoubleTapGestureRecognizer(),
                  (r) => r.onDoubleTap = _resetCamera,
                ),
          },
          child: ClipRect(
            child: Transform.translate(
              key: const ValueKey('dive3dViewportPan'),
              offset: _pan,
              child: painted,
            ),
          ),
        );

        final interactive = Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _zoomBy(signal.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
            }
          },
          onPointerPanZoomStart: _onPanZoomStart,
          onPointerPanZoomUpdate: _onPanZoomUpdate,
          child: hasChrome
              ? MouseRegion(
                  onHover: (e) => _pickAt(size, e.localPosition),
                  onExit: (_) => widget.hoverPick!.value = null,
                  child: gestures,
                )
              : gestures,
        );

        return Stack(
          children: [
            Positioned.fill(child: interactive),
            Positioned(
              top: 0,
              bottom: 0,
              right: 8,
              child: Center(child: _zoomControls(context)),
            ),
          ],
        );
      },
    );
  }

  Widget _zoomControls(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _zoomButton(
          context,
          Icons.add,
          () => _zoomBy(1.2),
          tooltip: context.l10n.dive3d_zoomIn,
        ),
        const SizedBox(height: 6),
        _zoomButton(
          context,
          Icons.remove,
          () => _zoomBy(1 / 1.2),
          tooltip: context.l10n.dive3d_zoomOut,
        ),
        const SizedBox(height: 6),
        _zoomButton(
          context,
          Icons.center_focus_strong,
          _resetCamera,
          tooltip: context.l10n.dive3d_resetView,
        ),
      ],
    );
  }

  Widget _zoomButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed, {
    String? tooltip,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.7),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
      ),
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
    paintScrubCursor(canvas, center);
  }

  @override
  bool shouldRepaint(covariant _ScrubCursorPainter oldDelegate) =>
      !identical(oldDelegate.scene, scene) ||
      oldDelegate.yawDegrees != yawDegrees ||
      oldDelegate.pitchDegrees != pitchDegrees ||
      oldDelegate.zoom != zoom ||
      oldDelegate.style != style;
}
