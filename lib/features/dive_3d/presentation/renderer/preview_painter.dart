import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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

  /// Stitched map-tile mosaic draped over the terrain-merged group; null
  /// paints vertex colors only.
  final ui.Image? terrainImagery;

  /// Normalized coordinates of the mosaic's reserved white texel; UV-less
  /// meshes in the merged group sample it so BlendMode.modulate leaves
  /// their vertex colors untouched.
  final ({double u, double v})? imageryWhiteTexel;

  const Dive3dScenePainter({
    required this.scene,
    this.yawDegrees = -32,
    this.pitchDegrees = 22,
    this.zoom = 1.0,
    this.visibleOverlays,
    this.terrainImagery,
    this.imageryWhiteTexel,
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

  static bool _overlayVisible(
    SceneOverlay? overlay,
    Set<SceneOverlay>? visibleOverlays,
  ) =>
      overlay == null ||
      visibleOverlays == null ||
      visibleOverlays.contains(overlay);

  /// Splits the scene's visible layers into the terrain-draped merge group
  /// and the rest. The group is the first visible layer (the terrain) plus
  /// every visible [SceneLayer.drapedOnTerrain] layer: their triangles are
  /// depth-sorted TOGETHER so far-side contours and walls hide behind
  /// hills. Everything else keeps plain back-to-front layer order.
  @visibleForTesting
  static ({List<MeshData> merged, List<MeshData> rest}) partitionLayers(
    Scene3d scene,
    Set<SceneOverlay>? visibleOverlays,
  ) {
    final merged = <MeshData>[];
    final rest = <MeshData>[];
    for (final layer in scene.layers) {
      if (!_overlayVisible(layer.overlay, visibleOverlays)) continue;
      if (merged.isEmpty || layer.drapedOnTerrain) {
        merged.add(layer.mesh);
      } else {
        rest.add(layer.mesh);
      }
    }
    return (merged: merged, rest: rest);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final projector = SceneProjector(
      size: size,
      bounds: scene.bounds,
      yawDegrees: yawDegrees,
      pitchDegrees: pitchDegrees,
      zoom: zoom,
    );
    final parts = partitionLayers(scene, visibleOverlays);
    // Only the terrain-merged group textures; rest layers (paths, pins,
    // water) always paint their own vertex colors.
    _paintMeshes(
      canvas,
      projector,
      parts.merged,
      imagery: terrainImagery,
      whiteTexel: imageryWhiteTexel,
    );
    for (final mesh in parts.rest) {
      _paintMeshes(canvas, projector, [mesh]);
    }
    if (_visible(SceneOverlay.markers)) _paintMarkers(canvas, projector);
  }

  /// Per-global-vertex texture coordinates for a merged soup, in IMAGE
  /// PIXELS (ImageShader space under an identity matrix). Meshes without
  /// UVs sample the reserved white texel so BlendMode.modulate leaves
  /// their vertex colors untouched.
  @visibleForTesting
  static Float32List soupTextureCoords(
    List<MeshData> meshes,
    ({double u, double v}) whiteTexel,
    int imageWidth,
    int imageHeight,
  ) {
    var vn = 0;
    for (final mesh in meshes) {
      vn += mesh.vertexCount;
    }
    final coords = Float32List(vn * 2);
    var vOff = 0;
    for (final mesh in meshes) {
      final uv = mesh.textureCoordinates;
      for (var i = 0; i < mesh.vertexCount; i++) {
        final gi = (vOff + i) * 2;
        if (uv != null) {
          coords[gi] = uv[i * 2] * imageWidth;
          coords[gi + 1] = uv[i * 2 + 1] * imageHeight;
        } else {
          coords[gi] = whiteTexel.u * imageWidth;
          coords[gi + 1] = whiteTexel.v * imageHeight;
        }
      }
      vOff += mesh.vertexCount;
    }
    return coords;
  }

  /// Paints one or more meshes as a single depth-sorted triangle soup.
  /// Multi-mesh calls exist for the terrain-draped group; each triangle
  /// keeps its source mesh's opacity. When [imagery] and [whiteTexel] are
  /// present and any mesh carries UVs, the soup draws through an
  /// ImageShader modulated by the (shaded) vertex colors.
  void _paintMeshes(
    Canvas canvas,
    SceneProjector projector,
    List<MeshData> meshes, {
    ui.Image? imagery,
    ({double u, double v})? whiteTexel,
  }) {
    var vn = 0;
    var triCount = 0;
    for (final mesh in meshes) {
      vn += mesh.vertexCount;
      triCount += mesh.triangleCount;
    }
    if (vn == 0 || triCount == 0) return;

    Float32List? vertexTex;
    if (imagery != null &&
        whiteTexel != null &&
        meshes.any((m) => m.textureCoordinates != null)) {
      vertexTex = soupTextureCoords(
        meshes,
        whiteTexel,
        imagery.width,
        imagery.height,
      );
    }

    // Rotate every vertex into view space once: (vx,vy,vz) drive both the
    // face normals and the depth sort, (sx,sy) are the canvas points.
    // Vertices and triangles from all meshes concatenate with an offset;
    // per-triangle alpha carries each source mesh's opacity.
    final vx = Float32List(vn);
    final vy = Float32List(vn);
    final vz = Float32List(vn);
    // Depth the sort uses: vz, except where a mesh declares sort heights.
    final vzSort = Float32List(vn);
    final sx = Float32List(vn);
    final sy = Float32List(vn);
    final vColors = Float32List(vn * 3);
    final triIndices = Uint32List(triCount * 3);
    final triAlpha = Int32List(triCount);
    var vOff = 0;
    var tOff = 0;
    for (final mesh in meshes) {
      final alpha = (mesh.opacity * 255).round() << 24;
      final sortHeights = mesh.sortHeights;
      for (var i = 0; i < mesh.vertexCount; i++) {
        final gi = vOff + i;
        final v = projector.viewOf(
          mesh.positions[i * 3],
          mesh.positions[i * 3 + 1],
          mesh.positions[i * 3 + 2],
        );
        vx[gi] = v.$1;
        vy[gi] = v.$2;
        vz[gi] = v.$3;
        vzSort[gi] = sortHeights == null
            ? v.$3
            : v.$3 +
                  (sortHeights[i] - mesh.positions[i * 3 + 1]) *
                      projector.depthPerUnitY;
        final o = projector.projectView(v);
        sx[gi] = o.dx;
        sy[gi] = o.dy;
        vColors[gi * 3] = mesh.colors[i * 3];
        vColors[gi * 3 + 1] = mesh.colors[i * 3 + 1];
        vColors[gi * 3 + 2] = mesh.colors[i * 3 + 2];
      }
      for (var t = 0; t < mesh.triangleCount; t++) {
        final gt = tOff + t;
        triIndices[gt * 3] = mesh.indices[t * 3] + vOff;
        triIndices[gt * 3 + 1] = mesh.indices[t * 3 + 1] + vOff;
        triIndices[gt * 3 + 2] = mesh.indices[t * 3 + 2] + vOff;
        triAlpha[gt] = alpha;
      }
      vOff += mesh.vertexCount;
      tOff += mesh.triangleCount;
    }

    // Depth-sort triangles back-to-front by mean view depth, taken at each
    // mesh's sort heights where it declares them.
    final order = List<int>.generate(triCount, (i) => i);
    final depths = Float32List(triCount);
    for (var t = 0; t < triCount; t++) {
      final i0 = triIndices[t * 3];
      final i1 = triIndices[t * 3 + 1];
      final i2 = triIndices[t * 3 + 2];
      depths[t] = (vzSort[i0] + vzSort[i1] + vzSort[i2]) / 3;
    }
    order.sort((a, b) => depths[a].compareTo(depths[b]));

    // De-index into flat-shaded triangles: each triangle owns its 3 vertices
    // so it can carry its own face-normal brightness. drawVertices only
    // interpolates colors, so shading has to be baked into those colors here.
    final screen = Float32List(triCount * 3 * 2);
    final colors = Int32List(triCount * 3);
    final texOut = vertexTex == null ? null : Float32List(triCount * 3 * 2);
    final tex = vertexTex;

    void emit(int slot, int vi, double shade, int alpha) {
      screen[slot * 2] = sx[vi];
      screen[slot * 2 + 1] = sy[vi];
      if (texOut != null) {
        texOut[slot * 2] = tex![vi * 2];
        texOut[slot * 2 + 1] = tex[vi * 2 + 1];
      }
      final r = ((vColors[vi * 3] * shade).clamp(0.0, 1.0) * 255).round();
      final g = ((vColors[vi * 3 + 1] * shade).clamp(0.0, 1.0) * 255).round();
      final b = ((vColors[vi * 3 + 2] * shade).clamp(0.0, 1.0) * 255).round();
      colors[slot] = alpha | (r << 16) | (g << 8) | b;
    }

    for (var t = 0; t < triCount; t++) {
      final tri = order[t];
      final i0 = triIndices[tri * 3];
      final i1 = triIndices[tri * 3 + 1];
      final i2 = triIndices[tri * 3 + 2];

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
      emit(tv, i0, shade, triAlpha[tri]);
      emit(tv + 1, i1, shade, triAlpha[tri]);
      emit(tv + 2, i2, shade, triAlpha[tri]);
    }

    if (texOut != null) {
      canvas.drawVertices(
        ui.Vertices.raw(
          ui.VertexMode.triangles,
          screen,
          colors: colors,
          textureCoordinates: texOut,
        ),
        BlendMode.modulate,
        Paint()
          ..shader = ui.ImageShader(
            imagery!,
            TileMode.clamp,
            TileMode.clamp,
            Matrix4.identity().storage,
          ),
      );
    } else {
      canvas.drawVertices(
        ui.Vertices.raw(ui.VertexMode.triangles, screen, colors: colors),
        BlendMode.dst,
        Paint(),
      );
    }
  }

  void _paintMarkers(Canvas canvas, SceneProjector projector) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final marker in scene.markers) {
      // Diver-placed features have their own overlay gate, so they can be
      // hidden without losing the site and nearby-site pins.
      if (marker.kind == SceneMarkerKind.siteFeature &&
          !_visible(SceneOverlay.features)) {
        continue;
      }
      paint.color = switch (marker.kind) {
        SceneMarkerKind.gasSwitch => const Color(0xFF22C55E),
        SceneMarkerKind.bookmark => const Color(0xFFF59E0B),
        SceneMarkerKind.photo => const Color(0xFF00D4FF),
        SceneMarkerKind.site => const Color(0xFFF43F5E),
        SceneMarkerKind.nearbySite => const Color(0xFF94A3B8),
        SceneMarkerKind.siteFeature => const Color(0xFF14B8A6),
      };
      canvas.drawCircle(
        projector.project(marker.x, marker.y, marker.z),
        4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant Dive3dScenePainter oldDelegate) =>
      !identical(oldDelegate.scene, scene) ||
      oldDelegate.yawDegrees != yawDegrees ||
      oldDelegate.pitchDegrees != pitchDegrees ||
      oldDelegate.zoom != zoom ||
      oldDelegate.visibleOverlays != visibleOverlays ||
      !identical(oldDelegate.terrainImagery, terrainImagery) ||
      oldDelegate.imageryWhiteTexel != imageryWhiteTexel;
}
