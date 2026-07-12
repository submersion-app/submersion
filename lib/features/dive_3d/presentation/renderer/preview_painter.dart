import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

/// Paints a Scene3d through SceneProjector with drawVertices. Layers paint
/// back-to-front in list order and triangles within each mesh are
/// depth-sorted, which is sufficient painter's-algorithm ordering for the
/// scene's layered translucency. This is the app's one 3D rasterizer: the
/// preview card paints it with the default camera, the interactive
/// viewport drives the camera parameters from gestures. Layers whose
/// overlay is toggled off (and markers when the markers overlay is off)
/// are skipped.
class Dive3dScenePainter extends CustomPainter {
  final Scene3d scene;
  final double yawDegrees;
  final double pitchDegrees;
  final double zoom;
  final Set<SceneOverlay>? visibleOverlays;

  const Dive3dScenePainter({
    required this.scene,
    this.yawDegrees = -32,
    this.pitchDegrees = 22,
    this.zoom = 1.0,
    this.visibleOverlays,
  });

  // Studio lighting for flat shading. Ambient is the floor every surface
  // keeps (so all hues stay readable); the diffuse term adds the
  // shape-revealing gradient that plain vertex colors lacked. The light
  // sits up / slightly left / toward the viewer, in view space.
  static const double _ambient = 0.45;
  static const double _diffuse = 0.55;
  static final List<double> _lightDir = _normalize(-0.35, 0.78, 0.52);

  static List<double> _normalize(double x, double y, double z) {
    final len = math.sqrt(x * x + y * y + z * z);
    if (len < 1e-12) return const [0, 0, 1];
    return [x / len, y / len, z / len];
  }

  bool _visible(SceneOverlay? overlay) =>
      overlay == null ||
      visibleOverlays == null ||
      visibleOverlays!.contains(overlay);

  @override
  void paint(Canvas canvas, Size size) {
    final projector = SceneProjector(
      size: size,
      bounds: scene.bounds,
      yawDegrees: yawDegrees,
      pitchDegrees: pitchDegrees,
      zoom: zoom,
    );
    for (final layer in scene.layers) {
      if (_visible(layer.overlay)) _paintMesh(canvas, projector, layer.mesh);
    }
    if (_visible(SceneOverlay.markers)) _paintMarkers(canvas, projector);
  }

  void _paintMesh(Canvas canvas, SceneProjector projector, MeshData mesh) {
    final vn = mesh.vertexCount;
    final triCount = mesh.triangleCount;
    if (vn == 0 || triCount == 0) return;

    // Rotate every vertex into view space once: (vx,vy,vz) drive both the
    // face normals and the depth sort, (sx,sy) are the canvas points.
    final vx = Float32List(vn);
    final vy = Float32List(vn);
    final vz = Float32List(vn);
    final sx = Float32List(vn);
    final sy = Float32List(vn);
    for (var i = 0; i < vn; i++) {
      final v = projector.viewOf(
        mesh.positions[i * 3],
        mesh.positions[i * 3 + 1],
        mesh.positions[i * 3 + 2],
      );
      vx[i] = v.$1;
      vy[i] = v.$2;
      vz[i] = v.$3;
      final o = projector.projectView(v);
      sx[i] = o.dx;
      sy[i] = o.dy;
    }

    // Depth-sort triangles back-to-front by mean view depth.
    final order = List<int>.generate(triCount, (i) => i);
    final depths = Float32List(triCount);
    for (var t = 0; t < triCount; t++) {
      final i0 = mesh.indices[t * 3];
      final i1 = mesh.indices[t * 3 + 1];
      final i2 = mesh.indices[t * 3 + 2];
      depths[t] = (vz[i0] + vz[i1] + vz[i2]) / 3;
    }
    order.sort((a, b) => depths[a].compareTo(depths[b]));

    // De-index into flat-shaded triangles: each triangle owns its 3 vertices
    // so it can carry its own face-normal brightness. drawVertices only
    // interpolates colors, so shading has to be baked into those colors here.
    final alpha = (mesh.opacity * 255).round() << 24;
    final screen = Float32List(triCount * 3 * 2);
    final colors = Int32List(triCount * 3);

    void emit(int slot, int vi, double shade) {
      screen[slot * 2] = sx[vi];
      screen[slot * 2 + 1] = sy[vi];
      final r = ((mesh.colors[vi * 3] * shade).clamp(0.0, 1.0) * 255).round();
      final g = ((mesh.colors[vi * 3 + 1] * shade).clamp(0.0, 1.0) * 255)
          .round();
      final b = ((mesh.colors[vi * 3 + 2] * shade).clamp(0.0, 1.0) * 255)
          .round();
      colors[slot] = alpha | (r << 16) | (g << 8) | b;
    }

    for (var t = 0; t < triCount; t++) {
      final tri = order[t];
      final i0 = mesh.indices[tri * 3];
      final i1 = mesh.indices[tri * 3 + 1];
      final i2 = mesh.indices[tri * 3 + 2];

      // Face normal from two edges (cross product) in view space.
      final ax = vx[i1] - vx[i0], ay = vy[i1] - vy[i0], az = vz[i1] - vz[i0];
      final bx = vx[i2] - vx[i0], by = vy[i2] - vy[i0], bz = vz[i2] - vz[i0];
      var nx = ay * bz - az * by;
      var ny = az * bx - ax * bz;
      var nz = ax * by - ay * bx;
      var shade = _ambient;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (len > 1e-9) {
        nx /= len;
        ny /= len;
        nz /= len;
        // Light whichever face is toward the camera (+z) so orbiting below
        // the waterline never drops a surface into full shadow.
        if (nz < 0) {
          nx = -nx;
          ny = -ny;
          nz = -nz;
        }
        final d = nx * _lightDir[0] + ny * _lightDir[1] + nz * _lightDir[2];
        shade = _ambient + _diffuse * (d > 0 ? d : 0.0);
      }

      final tv = t * 3;
      emit(tv, i0, shade);
      emit(tv + 1, i1, shade);
      emit(tv + 2, i2, shade);
    }

    canvas.drawVertices(
      Vertices.raw(VertexMode.triangles, screen, colors: colors),
      BlendMode.dst,
      Paint(),
    );
  }

  void _paintMarkers(Canvas canvas, SceneProjector projector) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final marker in scene.markers) {
      paint.color = switch (marker.kind) {
        SceneMarkerKind.gasSwitch => const Color(0xFF22C55E),
        SceneMarkerKind.bookmark => const Color(0xFFF59E0B),
        SceneMarkerKind.photo => const Color(0xFF00D4FF),
      };
      canvas.drawCircle(projector.project(marker.x, marker.y, 0), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant Dive3dScenePainter oldDelegate) =>
      !identical(oldDelegate.scene, scene) ||
      oldDelegate.yawDegrees != yawDegrees ||
      oldDelegate.pitchDegrees != pitchDegrees ||
      oldDelegate.zoom != zoom ||
      oldDelegate.visibleOverlays != visibleOverlays;
}
