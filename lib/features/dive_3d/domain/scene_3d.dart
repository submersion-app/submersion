import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

/// One renderable mesh in a scene. A null [overlay] means the layer is
/// structural (grid, ribbon, tissue surface) and always drawn; a non-null
/// overlay is gated by the viewport's visible-overlays set.
class SceneLayer {
  final MeshData mesh;
  final SceneOverlay? overlay;

  const SceneLayer(this.mesh, {this.overlay});
}

/// The path the scrub cursor follows, as scene-space (x, y) nodes keyed by
/// normalized time (0..1). Engine-agnostic: every scene provides its own
/// nodes so the cursor rides the ribbon (dive), the surface top (tissue),
/// or the swim path (spatial) without the renderer knowing which.
class ScrubPath {
  final List<double> normalizedTimes;
  final List<double> xs;
  final List<double> ys;

  /// Optional Z track for genuinely 3D scenes (the spatial swim path).
  /// When null the cursor rides at z = 0 (depth-time scenes).
  final List<double>? zs;

  const ScrubPath({
    required this.normalizedTimes,
    required this.xs,
    required this.ys,
    this.zs,
  });

  /// The scene-space cursor point at normalized time [t], or null if empty.
  ({double x, double y, double z})? sceneAt(double t) {
    final n = normalizedTimes.length;
    if (n == 0) return null;
    if (t <= normalizedTimes.first) {
      return (x: xs.first, y: ys.first, z: zs?.first ?? 0);
    }
    if (t >= normalizedTimes.last) {
      return (x: xs.last, y: ys.last, z: zs?.last ?? 0);
    }
    var lo = 0, hi = n - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (normalizedTimes[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = normalizedTimes[hi] - normalizedTimes[lo];
    final f = span <= 0 ? 0.0 : (t - normalizedTimes[lo]) / span;
    double lerp(List<double> v) => v[lo] + (v[hi] - v[lo]) * f;
    return (x: lerp(xs), y: lerp(ys), z: zs == null ? 0.0 : lerp(zs!));
  }

  /// 2D convenience (x, y) for depth-time scenes.
  Offset? positionAt(double t) {
    final p = sceneAt(t);
    return p == null ? null : Offset(p.x, p.y);
  }
}

/// A complete renderable 3D scene: an ordered list of layers (painted
/// back-to-front), tappable markers, the fit bounds, and an optional
/// scrub-cursor path. The one type every dive_3d scene (dive, tissue,
/// career, spatial) produces and the one type the renderer consumes.
class Scene3d {
  final List<SceneLayer> layers;
  final List<SceneMarker> markers;
  final SceneBounds bounds;
  final ScrubPath? scrubPath;

  const Scene3d({
    required this.layers,
    required this.markers,
    required this.bounds,
    this.scrubPath,
  });
}
