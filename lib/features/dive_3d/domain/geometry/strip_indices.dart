import 'dart:typed_data';

/// Indices for a triangle strip of [pairCount] vertex pairs laid out as
/// (2i, 2i+1): two triangles per segment. Shared by every strip builder.
Uint32List stripIndices(int pairCount) {
  if (pairCount < 2) return Uint32List(0);
  final indices = Uint32List((pairCount - 1) * 6);
  var j = 0;
  for (var i = 0; i < pairCount - 1; i++) {
    final a = i * 2, b = i * 2 + 1, c = i * 2 + 2, d = i * 2 + 3;
    indices[j++] = a;
    indices[j++] = b;
    indices[j++] = c;
    indices[j++] = b;
    indices[j++] = d;
    indices[j++] = c;
  }
  return indices;
}
