import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/depth_sort.dart';

/// Everything the 3D painter keeps for one depth-sorted triangle soup (the
/// terrain-draped group, or one rest group) between frames.
///
/// Orbiting repaints the scene on every frame. Before this existed each
/// repaint allocated and refilled the concatenated indices, colors and
/// per-triangle flags, the projection buffers, the sort order and the
/// de-indexed vertex buffers: about 36 MiB of typed arrays for the finest
/// terrain grid alone (issue #4259). Here the mesh-derived data is built
/// once per set of meshes, the per-frame buffers are reused, and the sort,
/// shading and color emit are skipped when only the zoom or canvas size
/// changed, since the orthographic depth order and the face shading depend
/// on the camera's rotation alone.
class TriangleSoup {
  List<MeshData> _meshes = const [];

  int _vertexCount = 0;
  int _triangleCount = 0;
  int get vertexCount => _vertexCount;
  int get triangleCount => _triangleCount;

  // Mesh-derived: rebuilt only when [bind] sees different meshes.
  // Every mesh's triangles, with indices offset into the concatenated
  // vertices.
  Uint32List triIndices = Uint32List(0);
  // Each triangle's source-mesh opacity, as the alpha byte in place.
  Int32List triAlpha = Int32List(0);
  // 1 for triangles of a stroke mesh: drawn in their vertex colors as
  // given, since a line has no face to light.
  Uint8List triUnshaded = Uint8List(0);
  Float32List vertexColors = Float32List(0);
  bool hasTextureCoordinates = false;

  // Per-vertex frame buffers, refilled on every paint.
  Float32List vx = Float32List(0);
  Float32List vy = Float32List(0);
  Float32List vz = Float32List(0);
  Float32List vzSort = Float32List(0);
  Float32List sx = Float32List(0);
  Float32List sy = Float32List(0);

  // Per-triangle sort state, refilled when the camera rotates.
  Float32List depths = Float32List(0);
  Uint32List order = Uint32List(0);
  final DepthSortScratch sortScratch = DepthSortScratch();

  // drawVertices input. ui.Vertices copies these, so they can be refilled
  // in place on the next frame.
  Float32List screen = Float32List(0);
  Int32List colors = Int32List(0);
  Float32List? textureOut;

  /// Image-pixel texture coordinates per vertex, and the image size and
  /// white texel they were scaled for. Null when the soup is untextured.
  Float32List? vertexTexture;
  Object? _textureKey;

  /// The camera rotation and texture key that [order], [colors] and
  /// [textureOut] were last filled for; null when they are stale.
  Object? _emittedKey;

  /// How many times the mesh-derived data was built, and the triangles
  /// sorted. For tests that check the caching.
  @visibleForTesting
  int buildCount = 0;
  @visibleForTesting
  int sortCount = 0;

  /// Points the soup at [meshes], rebuilding the mesh-derived data and
  /// resizing the frame buffers only when they are not the meshes it was
  /// built from (compared by identity, in order).
  void bind(List<MeshData> meshes) {
    if (_sameMeshes(meshes)) return;
    _meshes = List.unmodifiable(meshes);
    buildCount++;
    _textureKey = null;
    vertexTexture = null;
    _emittedKey = null;

    var vn = 0;
    var tn = 0;
    for (final mesh in meshes) {
      vn += mesh.vertexCount;
      tn += mesh.triangleCount;
    }
    _vertexCount = vn;
    _triangleCount = tn;
    hasTextureCoordinates = meshes.any((m) => m.textureCoordinates != null);

    triIndices = Uint32List(tn * 3);
    triAlpha = Int32List(tn);
    triUnshaded = Uint8List(tn);
    vertexColors = Float32List(vn * 3);
    var vOff = 0;
    var tOff = 0;
    for (final mesh in meshes) {
      vertexColors.setRange(
        vOff * 3,
        (vOff + mesh.vertexCount) * 3,
        mesh.colors,
      );
      final alpha = (mesh.opacity * 255).round() << 24;
      final unshaded = mesh.strokeHalfWidthPx == null ? 0 : 1;
      for (var t = 0; t < mesh.triangleCount; t++) {
        final gt = tOff + t;
        triIndices[gt * 3] = mesh.indices[t * 3] + vOff;
        triIndices[gt * 3 + 1] = mesh.indices[t * 3 + 1] + vOff;
        triIndices[gt * 3 + 2] = mesh.indices[t * 3 + 2] + vOff;
        triAlpha[gt] = alpha;
        triUnshaded[gt] = unshaded;
      }
      vOff += mesh.vertexCount;
      tOff += mesh.triangleCount;
    }

    vx = Float32List(vn);
    vy = Float32List(vn);
    vz = Float32List(vn);
    vzSort = Float32List(vn);
    sx = Float32List(vn);
    sy = Float32List(vn);
    depths = Float32List(tn);
    order = Uint32List(tn);
    screen = Float32List(tn * 3 * 2);
    colors = Int32List(tn * 3);
    textureOut = null;
  }

  bool _sameMeshes(List<MeshData> meshes) {
    if (buildCount == 0 || meshes.length != _meshes.length) return false;
    for (var i = 0; i < meshes.length; i++) {
      if (!identical(meshes[i], _meshes[i])) return false;
    }
    return true;
  }

  /// Keeps [vertexTexture] in step with [key] (null for no texture),
  /// calling [build] only when the key changed. A change also marks the
  /// emitted buffers stale, since [textureOut] is copied from it.
  void syncTexture(Object? key, Float32List Function() build) {
    if (key == _textureKey) return;
    _textureKey = key;
    _emittedKey = null;
    if (key == null) {
      vertexTexture = null;
      textureOut = null;
    } else {
      vertexTexture = build();
      textureOut = Float32List(_triangleCount * 3 * 2);
    }
  }

  /// Whether [order], [colors] and [textureOut] already hold the output
  /// for [rotationKey]; when they do, only [screen] needs refilling.
  bool emittedFor(Object rotationKey) => _emittedKey == rotationKey;

  /// Records that the triangles were sorted and emitted for [rotationKey].
  void markEmitted(Object rotationKey) {
    sortCount++;
    _emittedKey = rotationKey;
  }
}

/// The 3D painter's buffers across frames: one [TriangleSoup] per paint
/// group, in paint order. The interactive viewport owns one for its
/// lifetime and hands it to every painter it builds, so camera moves reuse
/// the previous frame's memory instead of allocating it again.
class ScenePaintCache {
  final List<TriangleSoup> _soups = [];

  /// The soup for the paint group at [index], created on first use.
  TriangleSoup soupAt(int index) {
    while (_soups.length <= index) {
      _soups.add(TriangleSoup());
    }
    return _soups[index];
  }

  /// Drops the soups past [count], so a group that stopped painting (an
  /// overlay turned off, a lighter scene) does not keep its buffers alive.
  void retain(int count) {
    if (_soups.length > count) _soups.removeRange(count, _soups.length);
  }

  @visibleForTesting
  int get soupCount => _soups.length;
}
