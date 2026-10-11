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

  /// Set on a stroke: a strip whose vertices come in pairs along a
  /// centerline, both members of a pair at the same scene position. The
  /// renderer pushes each pair apart ON THE CANVAS, this many logical
  /// pixels to either side of the on-screen run, so the line keeps one
  /// width at every zoom and pitch and is never shaded as a surface.
  ///
  /// A width in scene units is a real-world distance: it grew with the
  /// terrain when zooming in and, on a hillside, one edge ended up under
  /// the surface (issue #3215). Null draws the mesh as given.
  ///
  /// Builders put two pairs on every interior point, and on the closing
  /// point of a closed line: the renderer ends the arriving leg and starts
  /// the leaving one at full width, and the quad between the two pairs
  /// fills the corner as a bevel.
  final double? strokeHalfWidthPx;

  // Not const: typed-data lists never are, and the stroke assert below
  // walks the positions.
  MeshData({
    required this.positions,
    required this.indices,
    required this.colors,
    this.opacity = 1.0,
    this.textureCoordinates,
    this.sortHeights,
    this.strokeHalfWidthPx,
  }) : assert(
         sortHeights == null || sortHeights.length * 3 == positions.length,
         'sortHeights needs exactly one entry per vertex: the renderer '
         'indexes it by vertex while building the depth key',
       ),
       assert(
         strokeHalfWidthPx == null || _pairsCoincide(positions),
         'a stroke is made of vertex pairs: two xyz triplets per centerline '
         'point, both at the same position',
       );

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;

  static bool _pairsCoincide(Float32List positions) {
    if (positions.length % 6 != 0) return false;
    for (var i = 0; i < positions.length; i += 6) {
      if (positions[i] != positions[i + 3] ||
          positions[i + 1] != positions[i + 4] ||
          positions[i + 2] != positions[i + 5]) {
        return false;
      }
    }
    return true;
  }
}
