import 'dart:math' as math;

import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// One row of the Gas consumption by segment card: a phase or a cylinder,
/// which the dive may have visited more than once.
///
/// A group keeps its separate stretches rather than becoming one segment from
/// the first start to the last end, because that span would count whatever
/// happened between the stretches. An ascent split by a safety stop spent only
/// its own minutes ascending.
class SacSegmentGroup {
  /// The stretches in this group, in dive order. Never empty.
  final List<SacSegment> segments;

  /// Time spent in this group, in seconds.
  final int durationSeconds;

  /// Duration-weighted average depth (meters).
  final double avgDepth;

  SacSegmentGroup(this.segments)
    : durationSeconds = segments.fold(0, (sum, s) => sum + s.durationSeconds),
      avgDepth = _weightedDepth(segments);

  DivePhase? get phase => segments.first.phase;

  String get label => segments.first.displayLabel;

  /// Whether [timestamp] (seconds from dive start) falls in any stretch.
  bool containsTimestamp(int timestamp) => segments.any(
    (s) => timestamp >= s.startTimestamp && timestamp <= s.endTimestamp,
  );

  static double _weightedDepth(List<SacSegment> segments) {
    final totalSeconds = segments.fold(0, (sum, s) => sum + s.durationSeconds);
    if (totalSeconds <= 0) {
      return segments.fold(0.0, (sum, s) => sum + s.avgDepth) / segments.length;
    }
    return segments.fold(
          0.0,
          (sum, s) => sum + s.avgDepth * s.durationSeconds,
        ) /
        totalSeconds;
  }
}

/// Groups [segments] by dive phase, in the order each phase first appears.
///
/// A segment with no phase has no row to join and is left out.
List<SacSegmentGroup> groupSegmentsByPhase(List<SacSegment> segments) =>
    _groupBy(segments.where((s) => s.phase != null), (s) => s.phase);

/// Groups [segments] by cylinder, in the order each cylinder is first used.
///
/// Divers switching back and forth, as on sidemount, would otherwise get a row
/// per switch.
List<SacSegmentGroup> groupSegmentsByCylinder(List<SacSegment> segments) =>
    _groupBy(segments, (s) => s.tankId ?? s.displayLabel);

/// The phase that covers the most of the stretch from [start] to [end], in
/// seconds, adding up a phase the stretch meets more than once. Null where no
/// phase covers any of it. A tie goes to the earlier phase.
DivePhase? dominantPhase(int start, int end, List<SacSegment> phaseSegments) {
  final seconds = <DivePhase, int>{};
  for (final segment in phaseSegments) {
    final phase = segment.phase;
    if (phase == null ||
        segment.endTimestamp < start ||
        segment.startTimestamp > end) {
      continue;
    }
    final int overlap =
        math.min(end, segment.endTimestamp) -
        math.max(start, segment.startTimestamp);
    // Touching a stretch at one end covers none of it. A zero-length stretch
    // has no time to cover, so there touching is all it can do.
    if (overlap <= 0 && end > start) continue;
    seconds[phase] = (seconds[phase] ?? 0) + overlap;
  }
  if (seconds.isEmpty) return null;
  return seconds.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

/// The rows of the card's Gas section: none on a dive that stayed on one
/// cylinder, where a single row would only repeat the Cylinders card.
List<SacSegmentGroup> gasSectionRows(List<SacSegment> segments) {
  final groups = groupSegmentsByCylinder(segments);
  return groups.length > 1 ? groups : const [];
}

List<SacSegmentGroup> _groupBy(
  Iterable<SacSegment> segments,
  Object? Function(SacSegment) key,
) {
  final groups = <Object?, List<SacSegment>>{};
  for (final segment in segments) {
    (groups[key(segment)] ??= []).add(segment);
  }
  return groups.values.map(SacSegmentGroup.new).toList();
}
