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
/// are skipped. Meshes that declare [MeshData.strokeHalfWidthPx] are
/// widened on the canvas after projection and drawn unshaded, so a line
/// stays a line at every zoom.
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
  /// hills. Everything else keeps plain back-to-front layer order, except
  /// that consecutive layers sharing the same non-null
  /// [SceneLayer.localMergeGroup] collapse into one [restGroups] entry,
  /// depth-sorted together instead of each painted as its own flat pass.
  @visibleForTesting
  static ({List<MeshData> merged, List<List<MeshData>> restGroups})
  partitionLayers(Scene3d scene, Set<SceneOverlay>? visibleOverlays) {
    final merged = <MeshData>[];
    final restGroups = <List<MeshData>>[];
    Object? openGroupKey;
    for (final layer in scene.layers) {
      if (!_overlayVisible(layer.overlay, visibleOverlays)) continue;
      if (merged.isEmpty || layer.drapedOnTerrain) {
        merged.add(layer.mesh);
        openGroupKey = null;
        continue;
      }
      final groupKey = layer.localMergeGroup;
      if (groupKey != null &&
          groupKey == openGroupKey &&
          restGroups.isNotEmpty) {
        restGroups.last.add(layer.mesh);
      } else {
        restGroups.add([layer.mesh]);
        openGroupKey = groupKey;
      }
    }
    return (merged: merged, restGroups: restGroups);
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
    // Imagery/whiteTexel are passed to EVERY _paintMeshes call, merged or
    // rest: a mesh without textureCoordinates (paths, pins, water, and
    // every rest layer before the LOD patch) is unaffected -- soupTextureCoords
    // samples the reserved white texel for it, which BlendMode.modulate
    // leaves as a no-op against its own vertex colors. The LOD patch
    // terrain (see site_seascape_providers.dart) is deliberately a rest
    // layer, not draped -- it still needs the map imagery drape like the
    // base terrain, just without sharing the base's depth sort.
    _paintMeshes(
      canvas,
      projector,
      parts.merged,
      imagery: terrainImagery,
      whiteTexel: imageryWhiteTexel,
    );
    for (final group in parts.restGroups) {
      _paintMeshes(
        canvas,
        projector,
        group,
        imagery: terrainImagery,
        whiteTexel: imageryWhiteTexel,
      );
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
    // 1 for triangles of a stroke mesh: drawn in their vertex colors as
    // given, since a line has no face to light.
    final triUnshaded = Uint8List(triCount);
    var vOff = 0;
    var tOff = 0;
    for (final mesh in meshes) {
      final alpha = (mesh.opacity * 255).round() << 24;
      final sortHeights = mesh.sortHeights;
      final strokeHalfWidthPx = mesh.strokeHalfWidthPx;
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
      if (strokeHalfWidthPx != null) {
        strokeScreenEdges(
          sx,
          sy,
          start: vOff,
          pairCount: mesh.vertexCount ~/ 2,
          halfWidthPx: strokeHalfWidthPx,
        );
      }
      for (var t = 0; t < mesh.triangleCount; t++) {
        final gt = tOff + t;
        triIndices[gt * 3] = mesh.indices[t * 3] + vOff;
        triIndices[gt * 3 + 1] = mesh.indices[t * 3 + 1] + vOff;
        triIndices[gt * 3 + 2] = mesh.indices[t * 3 + 2] + vOff;
        triAlpha[gt] = alpha;
        triUnshaded[gt] = strokeHalfWidthPx == null ? 0 : 1;
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
      var shade = triUnshaded[tri] != 0 ? 1.0 : _ambient;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (triUnshaded[tri] == 0 && len > 1e-9) {
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

  /// Dot product of two run normals past which a turn counts as a
  /// reversal: cos 150 degrees.
  static const double _reversalDot = -0.866;

  /// Longest corner edge, in half-widths: the miter of a right angle.
  static const double _miterLimit = math.sqrt2;

  /// Widens a stroke mesh on the canvas, [halfWidthPx] to either side of
  /// each vertex pair's point, with a bevel join at every corner. Builders
  /// put two pairs on each interior point (see `buildStrokeStrip`): on the
  /// inner side of the turn both pairs share the miter point, where the
  /// two legs' inner edges meet, so the legs neither overlap nor leave a
  /// gap there; on the outer side each pair ends its own leg square at
  /// full width, and the quad between the two pairs is the bevel triangle
  /// that fills the outer corner. The miter point is capped at
  /// [_miterLimit] half-widths, so a hairpin bevels instead of spiking.
  /// A run that turns back past [_reversalDot] has its normal flipped to
  /// agree with the one before, which keeps the leaving leg's two edges
  /// on the same sides as the arriving leg's rather than crossing into a
  /// bow-tie. A pair between two zero-length runs (a stationary stretch)
  /// keeps the side last used, before the first real run it faces that
  /// run, and a stationary stretch on a corner is joined like the corner.
  /// A line whose last pair sits exactly on its first (a closed isobath,
  /// see `buildStrokeStrip`) joins across that seam the same way. A lone
  /// pair with a real run on both sides (a stroke built without the
  /// doubled points) gets the capped miter on both sides. [sx]/[sy] are
  /// the projected canvas positions of every vertex in the soup; [start]
  /// is this mesh's first vertex. Both members of a pair sit on the same
  /// point (see [MeshData.strokeHalfWidthPx]), so the first member is read
  /// as the point.
  @visibleForTesting
  static void strokeScreenEdges(
    Float32List sx,
    Float32List sy, {
    required int start,
    required int pairCount,
    required double halfWidthPx,
  }) {
    if (pairCount == 0) return;
    final runs = pairCount - 1;
    // Unit normal of every run (pair j to pair j+1); (0, 0) for a
    // zero-length one.
    final nx = Float32List(runs);
    final ny = Float32List(runs);
    var firstReal = -1, lastReal = -1;
    for (var j = 0; j < runs; j++) {
      final a = start + j * 2;
      final dx = sx[a + 2] - sx[a];
      final dy = sy[a + 2] - sy[a];
      final len = math.sqrt(dx * dx + dy * dy);
      if (len <= 1e-6) continue;
      nx[j] = -dy / len;
      ny[j] = dx / len;
      if (firstReal < 0) firstReal = j;
      lastReal = j;
    }
    // Pair k's first member moves against (ax, ay), its second along
    // (bx, by).
    void write(int k, double ax, double ay, double bx, double by) {
      final a = start + k * 2;
      final x = sx[a], y = sy[a];
      sx[a] = x - ax * halfWidthPx;
      sy[a] = y - ay * halfWidthPx;
      sx[a + 1] = x + bx * halfWidthPx;
      sy[a + 1] = y + by * halfWidthPx;
    }

    if (firstReal < 0) {
      // Never moves: any side will do.
      for (var k = 0; k < pairCount; k++) {
        write(k, 0, 1, 0, 1);
      }
      return;
    }
    // Orient the normals consistently along the line: a run that turns
    // back past a hairpin has its normal flipped to agree with the one
    // before it.
    for (
      var j = firstReal + 1, px = nx[firstReal], py = ny[firstReal];
      j < runs;
      j++
    ) {
      if (nx[j] == 0 && ny[j] == 0) continue;
      if (nx[j] * px + ny[j] * py < _reversalDot) {
        nx[j] = -nx[j];
        ny[j] = -ny[j];
      }
      px = nx[j];
      py = ny[j];
    }
    final a0 = start, aN = start + runs * 2;
    final closed =
        pairCount > 2 &&
        (sx[aN] - sx[a0]).abs() <= 1e-6 &&
        (sy[aN] - sy[a0]).abs() <= 1e-6;
    // The forward chain above only keeps each run within 150 degrees of
    // the one before it, which says nothing about how the last run
    // compares to the first. The seam needs that same comparison too, but
    // nx[lastReal]/ny[lastReal] is ALSO the ordinary, already-correct
    // value the run right before it (an interior corner, not the seam)
    // reads as its OWN outgoing side: flipping it in place would fix the
    // seam and break that unrelated corner. Orient a local copy instead,
    // read only where a join genuinely crosses the seam.
    var seamInX = closed ? nx[lastReal] : 0.0;
    var seamInY = closed ? ny[lastReal] : 0.0;
    if (closed &&
        seamInX * nx[firstReal] + seamInY * ny[firstReal] < _reversalDot) {
      seamInX = -seamInX;
      seamInY = -seamInY;
    }
    var k = 0;
    while (k < pairCount) {
      // Pairs k..e sit on one point: the runs between them have no length.
      var e = k;
      while (e < runs && nx[e] == 0 && ny[e] == 0) {
        e++;
      }
      // The arriving side: the previous run, or, for the group that opens
      // the line, or the group right after the last real run (which can
      // only be the one that wraps to the first run, since no real run
      // follows the last one), the oriented copy that crosses the seam.
      final crossesSeam = closed && (k == 0 || k - 1 == lastReal);
      final inReal =
          crossesSeam || (k > 0 && (nx[k - 1] != 0 || ny[k - 1] != 0));
      final inX = crossesSeam
          ? seamInX
          : inReal
          ? nx[k - 1]
          : 0.0;
      final inY = crossesSeam
          ? seamInY
          : inReal
          ? ny[k - 1]
          : 0.0;
      // The leaving side: this run, or, for the group that closes the
      // line, the first run wrapping across the seam.
      var hasOut = e < runs;
      var outX = hasOut ? nx[e] : 0.0, outY = hasOut ? ny[e] : 0.0;
      if (!hasOut && closed && e == pairCount - 1) {
        hasOut = true;
        outX = nx[firstReal];
        outY = ny[firstReal];
      }
      if (inReal && hasOut) {
        // The orientation pass keeps the two within 150 degrees, so their
        // mean is never shorter than 2 cos 75 degrees.
        final mx = inX + outX, my = inY + outY;
        final len = math.sqrt(mx * mx + my * my);
        final scale = math.min(len / (mx * outX + my * outY), _miterLimit);
        final ex = mx / len * scale, ey = my / len * scale;
        if (e == k) {
          write(k, ex, ey, ex, ey);
        } else if (inX * outY - inY * outX > 0) {
          // Turning left: the inner side is the second member's.
          for (var j = k; j < e; j++) {
            write(j, inX, inY, ex, ey);
          }
          write(e, outX, outY, ex, ey);
        } else {
          for (var j = k; j < e; j++) {
            write(j, ex, ey, inX, inY);
          }
          write(e, ex, ey, outX, outY);
        }
      } else {
        final px = hasOut
            ? outX
            : inReal
            ? inX
            : 0.0;
        final py = hasOut
            ? outY
            : inReal
            ? inY
            : 1.0;
        for (var j = k; j <= e; j++) {
          write(j, px, py, px, py);
        }
      }
      k = e + 1;
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
