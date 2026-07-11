import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:three_js_angle_renderer/three_js_angle_renderer.dart';
import 'package:three_js_core/three_js_core.dart' as three;
import 'package:three_js_math/three_js_math.dart' as tmath;

import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/profile_lookup.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/three_adapter.dart';

enum SceneOverlay { strata, ceiling, curtain, markers }

/// Interactive three_js viewport for one dive. Orbit is hand-rolled
/// spherical-coordinate camera math (three_js_controls is excluded by
/// dependency constraints). The scrub cursor tracks [scrubPosition] inside
/// the render loop without any widget rebuilds. Any engine setup failure
/// fires [onInitFailure] so the page can fall back to the software
/// renderer.
class SceneViewport extends StatefulWidget {
  final Dive3dGeometry geometry;
  final ValueListenable<double> scrubPosition;
  final Set<SceneOverlay> visibleOverlays;
  final void Function(SceneMarker marker)? onMarkerTap;
  final VoidCallback? onInitFailure;

  const SceneViewport({
    super.key,
    required this.geometry,
    required this.scrubPosition,
    required this.visibleOverlays,
    this.onMarkerTap,
    this.onInitFailure,
  });

  @override
  State<SceneViewport> createState() => _SceneViewportState();
}

class _SceneViewportState extends State<SceneViewport> {
  late final ThreeJS threeJs;
  three.Mesh? _ribbon, _curtain, _strata, _ceiling;
  three.Mesh? _cursor;
  final List<three.Object3D> _markerSprites = [];
  bool _failed = false;
  bool _ready = false;

  // Orbit state: spherical coordinates around the scene center.
  static const double _initialYaw = 0.55;
  static const double _initialPitch = 0.35;
  static const double _initialRadius = 14.0;
  double _yaw = _initialYaw;
  double _pitch = _initialPitch;
  double _radius = _initialRadius;
  final tmath.Vector3 _target = tmath.Vector3(
    SceneBounds.xSpan / 2,
    -SceneBounds.ySpan / 2,
    0,
  );

  @override
  void initState() {
    super.initState();
    threeJs = ThreeJS(
      onSetupComplete: () {
        if (mounted) setState(() => _ready = true);
      },
      setup: _setup,
    );
  }

  Future<void> _setup() async {
    try {
      threeJs.scene = three.Scene();
      threeJs.camera = three.PerspectiveCamera(
        55,
        threeJs.width / threeJs.height,
        0.1,
        200,
      );
      _applyCamera();
      _buildSceneObjects();
    } catch (_) {
      _failed = true;
      widget.onInitFailure?.call();
    }
  }

  void _applyCamera() {
    final cp = math.cos(_pitch), sp = math.sin(_pitch);
    final cy = math.cos(_yaw), sy = math.sin(_yaw);
    threeJs.camera.position.setValues(
      _target.x + _radius * cp * sy,
      _target.y + _radius * sp,
      _target.z + _radius * cp * cy,
    );
    threeJs.camera.lookAt(_target);
  }

  void _buildSceneObjects() {
    final g = widget.geometry;
    _ribbon = ThreeAdapter.toMesh(g.ribbon);
    _curtain = ThreeAdapter.toMesh(g.curtain);
    threeJs.scene.add(_ribbon!);
    threeJs.scene.add(_curtain!);
    if (g.strata != null) {
      _strata = ThreeAdapter.toMesh(g.strata!);
      threeJs.scene.add(_strata!);
    }
    if (g.ceilingSurface != null) {
      _ceiling = ThreeAdapter.toMesh(g.ceilingSurface!);
      threeJs.scene.add(_ceiling!);
    }
    for (final marker in g.markers) {
      final sprite = _spriteFor(marker);
      _markerSprites.add(sprite);
      threeJs.scene.add(sprite);
    }
    final cursorGeometry = three.SphereGeometry(0.12);
    final cursorMaterial = three.MeshBasicMaterial.fromMap({'color': 0xFFFFFF});
    _cursor = three.Mesh(cursorGeometry, cursorMaterial);
    threeJs.scene.add(_cursor!);
    threeJs.addAnimationEvent((dt) => _updateCursor());
    _applyVisibility();
  }

  three.Object3D _spriteFor(SceneMarker marker) {
    final color = switch (marker.kind) {
      SceneMarkerKind.gasSwitch => 0x22C55E,
      SceneMarkerKind.bookmark => 0xF59E0B,
      SceneMarkerKind.photo => 0x00D4FF,
    };
    final sprite = three.Sprite(three.SpriteMaterial.fromMap({'color': color}));
    sprite.position.setValues(marker.x, marker.y, 0);
    sprite.scale.setValues(0.25, 0.25, 1);
    return sprite;
  }

  void _updateCursor() {
    final cursor = _cursor;
    if (cursor == null) return;
    final g = widget.geometry;
    final t = widget.scrubPosition.value * g.bounds.durationSeconds;
    // Ribbon vertex pairs are ordered by time and ribbon x is monotonic
    // in time, so interpolating y over x along the pair-leading vertices
    // tracks the ribbon exactly.
    final xs = <double>[
      for (var i = 0; i < g.ribbon.vertexCount; i += 2)
        g.ribbon.positions[i * 3],
    ];
    final ys = <double?>[
      for (var i = 0; i < g.ribbon.vertexCount; i += 2)
        g.ribbon.positions[i * 3 + 1],
    ];
    final x = g.bounds.xOf(t);
    final y = ProfileLookup(xs).interpolate(ys, x) ?? 0;
    cursor.position.setValues(x, y, 0);
  }

  void _applyVisibility() {
    _strata?.visible = widget.visibleOverlays.contains(SceneOverlay.strata);
    _ceiling?.visible = widget.visibleOverlays.contains(SceneOverlay.ceiling);
    _curtain?.visible = widget.visibleOverlays.contains(SceneOverlay.curtain);
    final markersVisible = widget.visibleOverlays.contains(
      SceneOverlay.markers,
    );
    for (final s in _markerSprites) {
      s.visible = markersVisible;
    }
  }

  @override
  void didUpdateWidget(covariant SceneViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_failed || !_ready) return;
    if (!identical(oldWidget.geometry, widget.geometry)) {
      threeJs.scene.clear();
      _markerSprites.clear();
      _buildSceneObjects();
    } else if (oldWidget.visibleOverlays != widget.visibleOverlays) {
      _applyVisibility();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_failed || !_ready) return;
    _yaw -= details.delta.dx * 0.01;
    _pitch = (_pitch + details.delta.dy * 0.01).clamp(-1.4, 1.4);
    _applyCamera();
  }

  void _zoomBy(double factor) {
    if (_failed || !_ready) return;
    _radius = (_radius / factor).clamp(3.0, 60.0);
    _applyCamera();
  }

  void _resetCamera() {
    _yaw = _initialYaw;
    _pitch = _initialPitch;
    _radius = _initialRadius;
    _applyCamera();
  }

  void _handleTapUp(TapUpDetails details) {
    final onTap = widget.onMarkerTap;
    if (onTap == null || _failed || !_ready) return;
    SceneMarker? best;
    var bestDistance = 24.0;
    for (final marker in widget.geometry.markers) {
      final v = tmath.Vector3(marker.x, marker.y, 0);
      v.project(threeJs.camera);
      final screen = Offset(
        (v.x + 1) / 2 * threeJs.width,
        (1 - v.y) / 2 * threeJs.height,
      );
      final d = (screen - details.localPosition).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = marker;
      }
    }
    if (best != null) onTap(best);
  }

  @override
  void dispose() {
    // ThreeJS.dispose touches late fields that only exist after a
    // successful setup; when GL init failed (or never ran, as under
    // flutter_test) disposing the host would throw LateInitializationError.
    try {
      threeJs.dispose();
    } catch (_) {
      // Engine never initialized; nothing was allocated.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return Listener(
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) {
          _zoomBy(signal.scrollDelta.dy < 0 ? 1.1 : 0.9);
        }
      },
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onDoubleTap: _resetCamera,
        onTapUp: _handleTapUp,
        child: threeJs.build(),
      ),
    );
  }
}
