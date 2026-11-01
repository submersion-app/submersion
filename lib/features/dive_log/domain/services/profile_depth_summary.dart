import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The depth columns a dive stores for the profile it shows.
typedef ProfileDepthSummary = ({double maxDepth, double avgDepth});

/// The depth summary of [points]: the deepest reading and the plain mean of
/// the readings, null when there are none.
///
/// This is what a dive stores when its live samples speak for it rather than a
/// computer's report, which is the case for a manual edit (issue #3931). A
/// source row keeps what its recording reported.
ProfileDepthSummary? profileDepthSummary(List<DiveProfilePoint> points) {
  if (points.isEmpty) return null;
  var maxDepth = 0.0;
  var depthSum = 0.0;
  for (final point in points) {
    if (point.depth > maxDepth) maxDepth = point.depth;
    depthSum += point.depth;
  }
  return (maxDepth: maxDepth, avgDepth: depthSum / points.length);
}
