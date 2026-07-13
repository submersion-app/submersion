import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Downsample a dive profile to a normalized polyline for tiny sparklines.
///
/// Buckets by time and keeps each bucket's maximum depth so short deep
/// excursions stay visible. Returns points with `t` in [0,1] (time) and
/// `depth` in [0,1] (1 = deepest sample). Profiles with fewer than two
/// samples return an empty list.
List<({double t, double depth})> sparklinePoints(
  List<DiveProfilePoint> profile, {
  int targetCount = 40,
}) {
  if (profile.length < 2) return const [];

  final first = profile.first.timestamp;
  final last = profile.last.timestamp;
  final span = last - first;
  if (span <= 0) return const [];

  double maxDepth = 0;
  for (final p in profile) {
    if (p.depth > maxDepth) maxDepth = p.depth;
  }
  if (maxDepth <= 0) return const [];

  final source = profile.length <= targetCount
      ? profile
      : _bucketMax(profile, targetCount);

  return [
    for (final p in source)
      (t: (p.timestamp - first) / span, depth: p.depth / maxDepth),
  ];
}

List<DiveProfilePoint> _bucketMax(
  List<DiveProfilePoint> profile,
  int targetCount,
) {
  final first = profile.first.timestamp;
  final span = profile.last.timestamp - first;
  final result = <DiveProfilePoint>[];
  var bucketIndex = -1;
  DiveProfilePoint? bucketBest;
  for (final p in profile) {
    final index = (((p.timestamp - first) / span) * (targetCount - 1)).floor();
    if (index != bucketIndex) {
      if (bucketBest != null) result.add(bucketBest);
      bucketIndex = index;
      bucketBest = p;
    } else if (p.depth > bucketBest!.depth) {
      bucketBest = p;
    }
  }
  if (bucketBest != null) result.add(bucketBest);
  return result;
}
