import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';

/// Downsample target per dive in the terrain (mini-profile resolution).
const int kCareerPointsPerDive = 120;

/// One terrain ribbon's depth-time shape: a dive's profile reduced to at
/// most [kCareerPointsPerDive] shape-preserving points, and its max depth.
///
/// What `CareerDiveInput` carries besides the dive's place in the set and
/// its date, which the set decides once every shape is known.
class CareerDiveShape {
  final double maxDepthMeters;
  final List<double> times; // seconds from descent
  final List<double> depths; // meters

  const CareerDiveShape({
    required this.maxDepthMeters,
    required this.times,
    required this.depths,
  });
}

/// The shape of a dive whose primary profile is [points], or null for one
/// the terrain skips: fewer than two samples, which is what a manual dive
/// has.
///
/// Keeps the endpoints, the deepest sample and each window's min/max
/// envelope ([decimateSeriesIndices]), so a brief excursion survives the
/// reduction rather than averaging away. Sorts by timestamp first: a merged
/// profile arrives in order, but the ribbon must never zigzag in time.
///
/// A top-level function with no captured state, so a batched read can send
/// it to a background isolate along with the blobs it reduces.
CareerDiveShape? careerDiveShapeOf(List<DiveProfilePoint> points) {
  if (points.length < 2) return null;
  final sorted = [...points]..sort((a, b) => a.timestamp - b.timestamp);
  final indices = decimateSeriesIndices([
    for (final p in sorted) p.depth,
  ], targetPoints: kCareerPointsPerDive);
  var maxDepth = 0.0;
  for (final p in sorted) {
    if (p.depth > maxDepth) maxDepth = p.depth;
  }
  return CareerDiveShape(
    maxDepthMeters: maxDepth,
    times: [for (final j in indices) sorted[j].timestamp.toDouble()],
    depths: [for (final j in indices) sorted[j].depth],
  );
}
