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

  /// Duration-weighted SAC rate (bar/min at surface).
  final double sacRate;

  /// Duration-weighted average depth (meters).
  final double avgDepth;

  SacSegmentGroup(this.segments)
    : durationSeconds = segments.fold(0, (sum, s) => sum + s.durationSeconds),
      sacRate = _weightedMean(segments, (s) => s.sacRate),
      avgDepth = _weightedMean(segments, (s) => s.avgDepth);

  DivePhase? get phase => segments.first.phase;

  String? get tankId => segments.first.tankId;

  String get label => segments.first.displayLabel;

  /// Whether [timestamp] (seconds from dive start) falls in any stretch.
  bool containsTimestamp(int timestamp) => segments.any(
    (s) => timestamp >= s.startTimestamp && timestamp <= s.endTimestamp,
  );

  static double _weightedMean(
    List<SacSegment> segments,
    double Function(SacSegment) value,
  ) {
    final totalSeconds = segments.fold(0, (sum, s) => sum + s.durationSeconds);
    if (totalSeconds <= 0) {
      return segments.fold(0.0, (sum, s) => sum + value(s)) / segments.length;
    }
    return segments.fold(0.0, (sum, s) => sum + value(s) * s.durationSeconds) /
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
