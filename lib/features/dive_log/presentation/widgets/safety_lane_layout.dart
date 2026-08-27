import 'dart:math' as math;

/// One tappable chip in the safety findings lane. [memberIndexes] holds the
/// indexes (into the caller's findings list) of every finding merged into
/// this chip, ascending by on-screen position; length > 1 marks a cluster.
class SafetyLaneChipPlacement {
  final double left;
  final double width;
  final List<int> memberIndexes;

  const SafetyLaneChipPlacement({
    required this.left,
    required this.width,
    required this.memberIndexes,
  });
}

/// Maps finding time ranges onto lane pixels: clamps to the visible window,
/// inflates every chip to [minChipWidth] (shifted to stay inside the lane),
/// and merges chips whose extents overlap into clusters. Pure geometry so
/// clustering behavior is unit-testable without widgets.
List<SafetyLaneChipPlacement> layoutSafetyLaneChips({
  required List<({double startSeconds, double endSeconds})> ranges,
  required double visibleMinSeconds,
  required double visibleMaxSeconds,
  required double laneWidth,
  double minChipWidth = 26.0,
}) {
  final window = visibleMaxSeconds - visibleMinSeconds;
  if (window <= 0 || laneWidth <= 0) return const [];

  final extents = <({double left, double right, int index})>[];
  for (var i = 0; i < ranges.length; i++) {
    final r = ranges[i];
    if (r.endSeconds < visibleMinSeconds ||
        r.startSeconds > visibleMaxSeconds) {
      continue;
    }
    var left = ((r.startSeconds - visibleMinSeconds) / window * laneWidth)
        .clamp(0.0, laneWidth);
    var right = ((r.endSeconds - visibleMinSeconds) / window * laneWidth).clamp(
      0.0,
      laneWidth,
    );
    if (right - left < minChipWidth) {
      final mid = (left + right) / 2;
      left = mid - minChipWidth / 2;
      right = mid + minChipWidth / 2;
      if (left < 0) {
        right -= left;
        left = 0;
      } else if (right > laneWidth) {
        left -= right - laneWidth;
        right = laneWidth;
      }
      left = math.max(left, 0.0);
      right = math.min(right, laneWidth);
    }
    extents.add((left: left, right: right, index: i));
  }
  extents.sort((a, b) => a.left.compareTo(b.left));

  final placements = <SafetyLaneChipPlacement>[];
  double clusterLeft = 0;
  double clusterRight = 0;
  var members = <int>[];
  for (final e in extents) {
    if (members.isEmpty) {
      clusterLeft = e.left;
      clusterRight = e.right;
      members = [e.index];
    } else if (e.left < clusterRight) {
      clusterRight = math.max(clusterRight, e.right);
      members.add(e.index);
    } else {
      placements.add(
        SafetyLaneChipPlacement(
          left: clusterLeft,
          width: clusterRight - clusterLeft,
          memberIndexes: members,
        ),
      );
      clusterLeft = e.left;
      clusterRight = e.right;
      members = [e.index];
    }
  }
  if (members.isNotEmpty) {
    placements.add(
      SafetyLaneChipPlacement(
        left: clusterLeft,
        width: clusterRight - clusterLeft,
        memberIndexes: members,
      ),
    );
  }
  return placements;
}
