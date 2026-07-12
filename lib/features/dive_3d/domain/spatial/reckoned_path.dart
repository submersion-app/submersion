/// One reconstructed point of the underwater swim path, in a local
/// east-north-up meter frame anchored at the entry point.
class ReckonedPoint {
  final double east; // meters east of entry
  final double north; // meters north of entry
  final double depth; // meters below surface (positive down)
  final double timeSeconds;

  const ReckonedPoint({
    required this.east,
    required this.north,
    required this.depth,
    required this.timeSeconds,
  });
}

/// The reconstructed swim path plus its horizontal/vertical extent and
/// whether it came from real compass headings (dead reckoning) or a
/// straight-line entry->exit fallback.
class ReckonedPath {
  final List<ReckonedPoint> points;
  final bool reconstructed;
  final double minEast, maxEast;
  final double minNorth, maxNorth;
  final double maxDepth;
  final double durationSeconds;

  const ReckonedPath({
    required this.points,
    required this.reconstructed,
    required this.minEast,
    required this.maxEast,
    required this.minNorth,
    required this.maxNorth,
    required this.maxDepth,
    required this.durationSeconds,
  });

  bool get isEmpty => points.isEmpty;
  double get eastSpan => (maxEast - minEast).abs();
  double get northSpan => (maxNorth - minNorth).abs();
}
