import 'dart:typed_data';

/// Engine-agnostic triangle mesh. Positions are xyz triplets in scene
/// units, colors are rgb triplets (0..1) per vertex. Opacity applies to
/// the whole mesh. Flat typed-data so meshes cross isolate boundaries
/// cheaply and upload to any renderer.
class MeshData {
  final Float32List positions;
  final Uint32List indices;
  final Float32List colors;
  final double opacity;

  /// Normalized uv pairs per vertex for renderers that texture the mesh;
  /// null for untextured meshes.
  final Float32List? textureCoordinates;

  /// Per-vertex scene Y to DEPTH-SORT at, when that differs from the Y the
  /// vertex is drawn at; null sorts at the drawn height.
  ///
  /// The renderer has no depth buffer: it orders triangles by their view-
  /// space centroid, which cannot resolve a small polygon lying on a large
  /// one. A contour ribbon riding a terrain cell that falls 100 m across
  /// its own width loses that comparison and gets painted over. Sorting
  /// such a mesh at the ceiling of the terrain cell it rides settles the
  /// tie in favor of the thing that is genuinely on top, while still
  /// drawing it where it belongs.
  final Float32List? sortHeights;

  const MeshData({
    required this.positions,
    required this.indices,
    required this.colors,
    this.opacity = 1.0,
    this.textureCoordinates,
    this.sortHeights,
  }) : assert(
         sortHeights == null || sortHeights.length * 3 == positions.length,
         'sortHeights needs exactly one entry per vertex: the renderer '
         'indexes it by vertex while building the depth key',
       );

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}
