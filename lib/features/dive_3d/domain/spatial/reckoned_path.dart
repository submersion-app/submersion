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

/// Where a [ReckonedPath]'s horizontal shape came from.
enum PathProvenance {
  /// A measured underwater route (e.g. a linked Seacraft ENC / Suunto
  /// route), adapted through `NavTrackPathAdapter`.
  measured,

  /// Dead reckoning from the dive computer's compass headings.
  deadReckoned,

  /// A straight entry->exit line: heading data was insufficient to dead
  /// reckon.
  straightLine,
}

/// The reconstructed swim path plus its horizontal/vertical extent and
/// whether it is a measured route, dead reckoning, or a straight-line
/// entry->exit fallback.
class ReckonedPath {
  final List<ReckonedPoint> points;

  /// Where this path's shape came from.
  final PathProvenance provenance;

  /// A human-readable caption for [PathProvenance.measured] paths (e.g. "
  /// Seacraft ENC"), or null when no more specific label is available.
  final String? sourceLabel;

  final double minEast, maxEast;
  final double minNorth, maxNorth;
  final double maxDepth;
  final double durationSeconds;

  const ReckonedPath({
    required this.points,
    PathProvenance? provenance,
    @Deprecated('Use provenance instead.') bool? reconstructed,
    this.sourceLabel,
    required this.minEast,
    required this.maxEast,
    required this.minNorth,
    required this.maxNorth,
    required this.maxDepth,
    required this.durationSeconds,
  }) : provenance =
           provenance ??
           (reconstructed == true
               ? PathProvenance.deadReckoned
               : PathProvenance.straightLine);

  /// Kept for existing call sites written before [PathProvenance] existed:
  /// true for anything but a straight-line fallback.
  bool get reconstructed => provenance != PathProvenance.straightLine;

  bool get isEmpty => points.isEmpty;
  double get eastSpan => (maxEast - minEast).abs();
  double get northSpan => (maxNorth - minNorth).abs();
}

/// Shifts a path into a shared local frame (e.g. a dive's entry offset
/// from the site pin). Identity when the anchor is the origin.
ReckonedPath offsetReckonedPath(
  ReckonedPath path,
  ({double east, double north}) anchor,
) {
  if (anchor.east == 0 && anchor.north == 0) return path;
  return ReckonedPath(
    points: [
      for (final p in path.points)
        ReckonedPoint(
          east: p.east + anchor.east,
          north: p.north + anchor.north,
          depth: p.depth,
          timeSeconds: p.timeSeconds,
        ),
    ],
    provenance: path.provenance,
    sourceLabel: path.sourceLabel,
    minEast: path.minEast + anchor.east,
    maxEast: path.maxEast + anchor.east,
    minNorth: path.minNorth + anchor.north,
    maxNorth: path.maxNorth + anchor.north,
    maxDepth: path.maxDepth,
    durationSeconds: path.durationSeconds,
  );
}
