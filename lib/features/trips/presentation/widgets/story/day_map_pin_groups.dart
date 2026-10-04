import 'dart:ui';

/// Groups pins whose screen [positions] sit closer than [radius] pixels,
/// directly or through a chain of near neighbours (issue #2883).
///
/// Positions are pixels at the map's current zoom, so the grouping follows
/// the camera: two sites a few metres apart collide at a day's fitted zoom
/// and come apart once the diver zooms in. Each group lists pin indexes in
/// order, and groups are ordered by their first pin, so the earliest dive
/// leads its group.
///
/// A positive [worldWidth] is the width of one world at that zoom: an x
/// distance is then measured the short way round, so pins either side of
/// the date line still collide.
List<List<int>> groupNearbyPins(
  List<Offset> positions, {
  required double radius,
  double worldWidth = 0,
}) {
  // Union-find: each pin starts as its own root, and every colliding pair
  // joins its two roots under the lower index.
  final parent = [for (var i = 0; i < positions.length; i++) i];
  int root(int i) {
    var r = i;
    while (parent[r] != r) {
      r = parent[r];
    }
    return r;
  }

  final radiusSquared = radius * radius;
  for (var i = 0; i < positions.length; i++) {
    for (var j = i + 1; j < positions.length; j++) {
      var dx = (positions[i].dx - positions[j].dx).abs();
      if (worldWidth > 0) {
        dx %= worldWidth;
        if (dx > worldWidth / 2) dx = worldWidth - dx;
      }
      final dy = positions[i].dy - positions[j].dy;
      if (dx * dx + dy * dy >= radiusSquared) continue;
      final a = root(i);
      final b = root(j);
      if (a == b) continue;
      if (a < b) {
        parent[b] = a;
      } else {
        parent[a] = b;
      }
    }
  }

  final byRoot = <int, List<int>>{};
  for (var i = 0; i < positions.length; i++) {
    byRoot.putIfAbsent(root(i), () => []).add(i);
  }
  return [...byRoot.values];
}
