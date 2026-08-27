import 'dart:ui';

/// Corner windows used to measure how much of the profile lives in each
/// corner of the chart. Sized generously (45% x 40%) so a card up to roughly
/// a third of the chart wide counts the curve it would actually cover.
const double _cornerWidthFraction = 0.45;
const double _cornerHeightFraction = 0.4;

/// Picks the fullscreen readout card's default corner: the one whose corner
/// window contains the fewest profile points.
///
/// [normalizedProfile] holds the dive profile as offsets normalized to the
/// chart: x = time fraction (0..1), y = depth fraction (0 = surface/top,
/// 1 = max depth/bottom) - the same orientation the chart draws.
///
/// Returns a [FractionalOffset]-style corner: (1, 0) top-right, (0, 0)
/// top-left, (1, 1) bottom-right, (0, 1) bottom-left. Ties prefer top-right
/// (the historical default), then top-left, bottom-right, bottom-left.
///
/// A typical dive is deep through the middle and shallow at both ends, so
/// this usually lands on a bottom corner - away from the end-of-dive ascent
/// tail that the old fixed top-right default sat on. A saved user-dragged
/// position always takes precedence over this default (see the fullscreen
/// page wiring).
Offset leastOccupiedReadoutCorner(List<Offset> normalizedProfile) {
  const corners = <Offset>[
    Offset(1, 0), // top-right: historical default, wins ties
    Offset(0, 0), // top-left
    Offset(1, 1), // bottom-right
    Offset(0, 1), // bottom-left
  ];
  if (normalizedProfile.isEmpty) return corners.first;

  var best = corners.first;
  var bestCount = 1 << 30;
  for (final corner in corners) {
    final window = Rect.fromLTWH(
      corner.dx == 0 ? 0 : 1 - _cornerWidthFraction,
      corner.dy == 0 ? 0 : 1 - _cornerHeightFraction,
      _cornerWidthFraction,
      _cornerHeightFraction,
    );
    // Inclusive on all edges: Rect.contains excludes right/bottom, but
    // normalized profiles always hold exact 1.0 values (the last sample's
    // time, the max-depth sample), which must count toward the right and
    // bottom corner windows.
    final count = normalizedProfile
        .where(
          (p) =>
              p.dx >= window.left &&
              p.dx <= window.right &&
              p.dy >= window.top &&
              p.dy <= window.bottom,
        )
        .length;
    if (count < bestCount) {
      bestCount = count;
      best = corner;
    }
  }
  return best;
}
