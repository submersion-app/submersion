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

  const MeshData({
    required this.positions,
    required this.indices,
    required this.colors,
    this.opacity = 1.0,
  });

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}
