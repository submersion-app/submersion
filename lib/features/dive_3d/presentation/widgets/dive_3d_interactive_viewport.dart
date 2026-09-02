import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/contour_builder.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/camera_pose.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
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

/// Which chrome the viewport composes around the scene painter.
/// `tissue`: frame behind + wireframe/overlay painters (needs surfaceGrid).
/// `axesOnly`: axes, labels, compass, contour labels in front (seascape).
/// `framed`: frame grid behind + axes/labels/guides in front (dive path).
enum SceneChromeMode { none, tissue, axesOnly, framed }

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

  /// Chrome composition around the scene; see [SceneChromeMode]. Every mode
  /// but `none` needs [axisFrame] and [chromeStyle]; `tissue` also needs
  /// [surfaceGrid] and [hoverPick].
  final SceneChromeMode chromeMode;

  /// The tissue surface lattice, consumed by the tissue wireframe and
  /// overlay painters only.
  final TissueSurfaceGrid? surfaceGrid;
  final AxisFrame? axisFrame;
  final AxisLabelSet? axisLabels;
  final TissueChromeStyle? chromeStyle;

  /// Hover picking, in any chrome mode: [picker] finds what sits under the
  /// cursor and [hoverPick] publishes it (screenPos in viewport-local,
  /// pan-included coordinates) for tooltips and the chrome ring.
  final HoverPicker? picker;
  final ValueNotifier<ScenePick?>? hoverPick;

  /// Shows the camera preset menu under the zoom controls (the path scene).
  final bool showPosePresets;

  /// Chart mode: a locked plan-view camera (from above, north-up,
  /// east-right via the mirrored chart pose). One-finger drag pans instead
  /// of rotating; double-tap resets to the chart pose.
  final bool chartMode;

  /// Labeled contour levels for the seascape chrome; null everywhere else.
  final List<ContourLabelSpec>? contourLabels;

  /// Stitched map-tile mosaic draped over the terrain (seascape imagery
  /// modes only); forwarded to the scene painter untouched.
  final ui.Image? terrainImagery;

  /// Normalized white-texel coordinates inside [terrainImagery]; UV-less
  /// draped meshes sample it so modulate blending leaves them unchanged.
  final ({double u, double v})? imageryWhiteTexel;

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
    this.picker,
    this.hoverPick,
    this.chromeMode = SceneChromeMode.none,
    this.showPosePresets = false,
    this.chartMode = false,
    this.contourLabels,
    this.terrainImagery,
    this.imageryWhiteTexel,
  });

  @override
  State<Dive3dInteractiveViewport> createState() =>
      _Dive3dInteractiveViewportState();
}

class _Dive3dInteractiveViewportState extends State<Dive3dInteractiveViewport> {
  static const double _minZoom = 0.4;
  static const double _maxZoom = 8.0;
  CameraPose _pose = CameraPose.defaultView;
  double _yaw = CameraPose.defaultView.yawDegrees;
  double _pitch = CameraPose.defaultView.pitchDegrees;
  double _zoom = 1.0;
  // Screen-space translation from panning (two-finger trackpad drag). Applied
  // as a Transform on the painted output; picks subtract it from the cursor.
  Offset _pan = Offset.zero;
  double _panZoomBaseZoom = 1.0;
  // Zoom at the moment the active touch pinch began; ScaleUpdateDetails.scale
  // is cumulative against the gesture start, not the previous tick.
  double _scaleGestureBaseZoom = 1.0;
  // Last laid-out size, captured in build so camera-change handlers (which lack
  // the LayoutBuilder constraints) can re-project the hover pick.
  Size? _lastLayoutSize;

  /// Snaps the camera to the pose the current mode calls for: the chart
  /// plan view, or the default orbit view.
  void _applyPose() {
    if (widget.chartMode) {
      _yaw = chartYawDegrees;
      _pitch = chartPitchDegrees;
    } else {
      _yaw = _pose.yawDegrees;
      _pitch = _pose.pitchDegrees;
    }
    _zoom = 1.0;
    _pan = Offset.zero;
  }

  void _selectPose(CameraPose pose) {
    setState(() {
      _pose = pose;
      _applyPose();
    });
    _refreshHoverAfterCameraChange();
  }

  @override
  void initState() {
    super.initState();
    _applyPose();
  }

  @override
  void didUpdateWidget(Dive3dInteractiveViewport old) {
    super.didUpdateWidget(old);
    if (old.chartMode != widget.chartMode) {
      setState(_applyPose);
      _refreshHoverAfterCameraChange();
    }
  }

  void _onScaleStart(ScaleStartDetails _) {
    _scaleGestureBaseZoom = _zoom;
  }

  /// One recognizer serves both touch gestures, because Flutter cannot run a
  /// pan and a scale recognizer in the same arena without one starving the
  /// other. Pointer count decides the meaning: one finger orbits (or pans the
  /// locked plan view in chart mode), two fingers pinch-zoom and pan. That is
  /// the mapping issue #1188 asked for, and it is the only zoom a touchscreen
  /// can reach -- pan/zoom pointer events are trackpad-only.
  void _onScaleUpdate(Size size, ScaleUpdateDetails details) {
    final delta = details.focalPointDelta;
    if (details.pointerCount < 2) {
      setState(() {
        if (widget.chartMode) {
          _pan += delta;
        } else {
          // Drag follows the object: dragging right spins it clockwise (yaw
          // up), dragging down tilts it toward the viewer.
          _yaw += delta.dx * 0.4;
          _pitch = (_pitch + delta.dy * 0.4).clamp(-80.0, 80.0);
        }
      });
      _refreshHoverAfterCameraChange();
      return;
    }
    setState(() {
      _setZoomAnchored(
        size,
        (_scaleGestureBaseZoom * details.scale).clamp(_minZoom, _maxZoom),
        focalPoint: details.localFocalPoint,
        focalDelta: delta,
      );
    });
    _refreshHoverAfterCameraChange();
  }

  /// Scales the camera to [next] while keeping the scene point that sat under
  /// the pinch's PREVIOUS focal point ([focalPoint] - [focalDelta]) welded to
  /// the fingers, then carries the focal point's own travel as a pan.
  ///
  /// [SceneProjector] scales the scene about the canvas center, and the pan
  /// Transform is applied on top, so a projected point lands at
  /// `center + zoom * v + pan`. Solving that for the pan that pins one point
  /// across a zoom change gives the single expression below; with
  /// `next == _zoom` it degenerates to a plain `_pan += focalDelta`.
  void _setZoomAnchored(
    Size size,
    double next, {
    required Offset focalPoint,
    Offset focalDelta = Offset.zero,
  }) {
    final ratio = next / _zoom;
    final center = Offset(size.width / 2, size.height / 2);
    _pan =
        focalPoint - center - (focalPoint - focalDelta - center - _pan) * ratio;
    _zoom = next;
  }

  void _zoomBy(double factor) {
    setState(() {
      _zoom = (_zoom * factor).clamp(_minZoom, _maxZoom);
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
      _zoom = (_panZoomBaseZoom * event.scale).clamp(_minZoom, _maxZoom);
    });
    _refreshHoverAfterCameraChange();
  }

  void _resetCamera() {
    setState(() {
      _pose = CameraPose.defaultView;
      _applyPose();
    });
    _refreshHoverAfterCameraChange();
  }

  // The ring re-projects the pick's world anchor every paint, but the
  // tooltip overlay lives outside the paint transform and is placed from the
  // published screenPos, so a camera change with a stationary cursor would
  // strand it. Re-derive screenPos so both stay locked to the point.
  void _refreshHoverAfterCameraChange() {
    final size = _lastLayoutSize;
    final notifier = widget.hoverPick;
    final pick = notifier?.value;
    if (size == null || notifier == null || pick == null) return;
    notifier.value = pick.withScreenPos(
      _projectorFor(size).project(pick.x, pick.y, pick.z) + _pan,
    );
  }

  // One projector per (camera, size, bounds): pickers cache projections by
  // projector identity, so a fresh instance per call would defeat them.
  SceneProjector? _projector;
  double? _projYaw, _projPitch, _projZoom;
  Size? _projSize;
  SceneBounds? _projBounds;

  SceneProjector _projectorFor(Size size) {
    final cached = _projector;
    if (cached != null &&
        _projYaw == _yaw &&
        _projPitch == _pitch &&
        _projZoom == _zoom &&
        _projSize == size &&
        identical(_projBounds, widget.scene.bounds)) {
      return cached;
    }
    final p = SceneProjector(
      size: size,
      bounds: widget.scene.bounds,
      yawDegrees: _yaw,
      pitchDegrees: _pitch,
      zoom: _zoom,
    );
    _projector = p;
    _projYaw = _yaw;
    _projPitch = _pitch;
    _projZoom = _zoom;
    _projSize = size;
    _projBounds = widget.scene.bounds;
    return p;
  }

  void _pickAt(Size size, Offset local) {
    final notifier = widget.hoverPick;
    final picker = widget.picker;
    if (notifier == null || picker == null) return;
    // Projections are computed without pan; the painted output is translated
    // by _pan, so map the cursor back into untranslated projection space and
    // republish screenPos in viewport-local (painted) space for the tooltip.
    final pick = picker.pick(_projectorFor(size), local - _pan);
    notifier.value = pick?.withScreenPos(pick.screenPos + _pan);
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
      // A hidden feature marker is not tappable either.
      if (marker.kind == SceneMarkerKind.siteFeature &&
          !widget.visibleOverlays.contains(SceneOverlay.features)) {
        continue;
      }
      final d =
          (projector.project(marker.x, marker.y, marker.z) - cursor).distance;
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
        // Without a frame there is nothing to draw: a seascape whose axes are
        // not ready yet (or a synthesized fallback) degrades to no chrome.
        final mode = widget.axisFrame == null || widget.chromeStyle == null
            ? SceneChromeMode.none
            : widget.chromeMode;
        final hasHover = widget.picker != null && widget.hoverPick != null;
        assert(
          mode != SceneChromeMode.tissue ||
              (widget.surfaceGrid != null && widget.hoverPick != null),
          'tissue chrome needs surfaceGrid and hoverPick',
        );

        final cursorPainter = _ScrubCursorPainter(
          scene: widget.scene,
          yawDegrees: _yaw,
          pitchDegrees: _pitch,
          zoom: _zoom,
          scrubPosition: widget.scrubPosition,
          style: widget.scrubCursor,
        );
        final scenePaint = CustomPaint(
          painter: Dive3dScenePainter(
            scene: widget.scene,
            yawDegrees: _yaw,
            pitchDegrees: _pitch,
            zoom: _zoom,
            visibleOverlays: widget.visibleOverlays,
            terrainImagery: widget.terrainImagery,
            imageryWhiteTexel: widget.imageryWhiteTexel,
          ),
          foregroundPainter: mode == SceneChromeMode.tissue
              ? TissueChromePainter(
                  scene: widget.scene,
                  grid: widget.surfaceGrid!,
                  frame: widget.axisFrame!,
                  style: widget.chromeStyle!,
                  yawDegrees: _yaw,
                  pitchDegrees: _pitch,
                  zoom: _zoom,
                  labels: widget.axisLabels,
                  textDirection: Directionality.of(context),
                )
              : cursorPainter,
          child: const SizedBox.expand(),
        );

        TissueFramePainter framePainter() => TissueFramePainter(
          bounds: widget.scene.bounds,
          frame: widget.axisFrame!,
          style: widget.chromeStyle!,
          yawDegrees: _yaw,
          pitchDegrees: _pitch,
          zoom: _zoom,
        );
        AxisChromePainter axisPainter({
          required bool guides,
          required bool compass,
        }) => AxisChromePainter(
          bounds: widget.scene.bounds,
          frame: widget.axisFrame!,
          labels: widget.axisLabels,
          style: widget.chromeStyle!,
          yawDegrees: _yaw,
          pitchDegrees: _pitch,
          zoom: _zoom,
          textDirection: Directionality.of(context),
          hoverPick: hasHover ? widget.hoverPick : null,
          hoverGuides: guides,
          showCompass: compass,
          markerLabels:
              guides && widget.visibleOverlays.contains(SceneOverlay.markers)
              ? widget.scene.markers
              : null,
          contourLabels: widget.contourLabels,
          panOffset: _pan,
        );

        final painted = switch (mode) {
          SceneChromeMode.none => scenePaint,
          // Frame grid draws behind the surface (paint order gives
          // occlusion); the hover marker + cursor draw on top.
          SceneChromeMode.tissue => CustomPaint(
            painter: framePainter(),
            foregroundPainter: TissueOverlayPainter(
              scene: widget.scene,
              grid: widget.surfaceGrid!,
              style: widget.chromeStyle!,
              yawDegrees: _yaw,
              pitchDegrees: _pitch,
              zoom: _zoom,
              scrubPosition: widget.scrubPosition,
              hoverPick: widget.hoverPick!,
            ),
            child: scenePaint,
          ),
          SceneChromeMode.axesOnly => CustomPaint(
            foregroundPainter: axisPainter(guides: false, compass: true),
            child: scenePaint,
          ),
          SceneChromeMode.framed => CustomPaint(
            painter: framePainter(),
            foregroundPainter: axisPainter(guides: true, compass: false),
            child: scenePaint,
          ),
        };

        final gestures = RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            // Rotate (one finger) and pinch-zoom + pan (two fingers) from
            // mouse/touch/stylus. Trackpad pan-zoom pointers stay with the
            // Listener below.
            _TouchScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _TouchScaleGestureRecognizer
                >(
                  () => _TouchScaleGestureRecognizer(
                    supportedDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.invertedStylus,
                      PointerDeviceKind.unknown,
                    },
                  ),
                  (r) => r
                    ..onStart = _onScaleStart
                    ..onUpdate = (details) => _onScaleUpdate(size, details),
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
          child: hasHover
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('dive3dZoomControls'),
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
        if (widget.showPosePresets) ...[
          const SizedBox(height: 6),
          Material(
            color: scheme.surface.withValues(alpha: 0.7),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: PopupMenuButton<CameraPose>(
              key: const ValueKey('dive3dPoseMenu'),
              position: PopupMenuPosition.over,
              icon: const Icon(Icons.threed_rotation, size: 20),
              tooltip: context.l10n.dive3d_pose_menu,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              onSelected: _selectPose,
              itemBuilder: (context) => [
                for (final pose in CameraPose.values)
                  PopupMenuItem(
                    value: pose,
                    child: Text(switch (pose) {
                      CameraPose.defaultView =>
                        context.l10n.dive3d_pose_default,
                      CameraPose.front => context.l10n.dive3d_pose_front,
                      CameraPose.side => context.l10n.dive3d_pose_side,
                      CameraPose.top => context.l10n.dive3d_pose_top,
                    }),
                  ),
              ],
            ),
          ),
        ],
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
