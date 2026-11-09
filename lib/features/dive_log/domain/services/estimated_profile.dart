import 'package:equatable/equatable.dart';

/// One corner of an [EstimatedProfile]'s outline.
class EstimatedProfilePoint extends Equatable {
  const EstimatedProfilePoint(this.seconds, this.depth);

  /// Seconds from the start of the dive.
  final double seconds;

  /// Depth in meters.
  final double depth;

  @override
  List<Object?> get props => [seconds, depth];
}

/// A generic outline of a dive that has no recorded profile, drawn from its
/// max depth and its runtime or bottom time (issue #4112).
///
/// It is a picture, not data: it is never stored, and nothing that reads
/// profile samples (analysis, statistics, safety review, export, sync) sees
/// it. It is deliberately its own type, not a list of profile samples, so it
/// cannot be handed to code that expects recorded samples.
///
/// The outline descends at [descentRate], stays at the max depth, and
/// ascends at [ascentRate], with a [stopDuration] stop at [stopDepth] on a
/// dive deeper than [stopThreshold]. When the times leave less room than
/// those rates need, the legs shrink in proportion.
class EstimatedProfile extends Equatable {
  const EstimatedProfile._(this.points);

  /// Meters per minute down.
  static const double descentRate = 18;

  /// Meters per minute up.
  static const double ascentRate = 9;

  /// Depth of the safety stop, in meters.
  static const double stopDepth = 5;

  /// Length of the safety stop, in seconds.
  static const double stopDuration = 180;

  /// A dive deeper than this, in meters, gets a safety stop.
  static const double stopThreshold = 10;

  /// The outline's corners, from the surface back to the surface.
  final List<EstimatedProfilePoint> points;

  /// The outline's deepest point, in meters.
  double get maxDepth =>
      points.map((p) => p.depth).reduce((a, b) => a > b ? a : b);

  /// When the outline reaches the surface again, in seconds.
  double get durationSeconds => points.last.seconds;

  /// The outline for a dive, or null when it lacks a depth or a time.
  ///
  /// [bottomTime] runs from leaving the surface to the start of the final
  /// ascent, so it places the ascent; [runtime] places the surfacing. One
  /// of them is enough. A bottom time at or past the runtime is ignored.
  static EstimatedProfile? estimate({
    required double? maxDepth,
    Duration? runtime,
    Duration? bottomTime,
  }) {
    if (maxDepth == null || maxDepth <= 0) return null;
    final runtimeSeconds = _positiveSeconds(runtime);
    var bottomSeconds = _positiveSeconds(bottomTime);
    if (runtimeSeconds != null &&
        bottomSeconds != null &&
        bottomSeconds >= runtimeSeconds) {
      bottomSeconds = null;
    }
    if (runtimeSeconds == null && bottomSeconds == null) return null;

    final hasStop = maxDepth > stopThreshold;
    var descent = _secondsFor(maxDepth, descentRate);
    var firstLeg = _secondsFor(
      hasStop ? maxDepth - stopDepth : maxDepth,
      ascentRate,
    );
    var stop = hasStop ? stopDuration : 0.0;
    var lastLeg = hasStop ? _secondsFor(stopDepth, ascentRate) : 0.0;
    final ascent = firstLeg + stop + lastLeg;

    final double ascentStart;
    final double end;
    if (bottomSeconds != null) {
      ascentStart = bottomSeconds;
      if (descent > ascentStart) descent = ascentStart;
      if (runtimeSeconds == null) {
        end = ascentStart + ascent;
      } else {
        end = runtimeSeconds;
        final window = end - ascentStart;
        if (window < ascent) {
          final scale = window / ascent;
          firstLeg *= scale;
          stop *= scale;
          lastLeg *= scale;
        } else {
          firstLeg += window - ascent;
        }
      }
    } else {
      end = runtimeSeconds!;
      final needed = descent + ascent;
      if (needed > end) {
        final scale = end / needed;
        descent *= scale;
        firstLeg *= scale;
        stop *= scale;
        lastLeg *= scale;
        ascentStart = descent;
      } else {
        ascentStart = end - ascent;
      }
    }

    final points = <EstimatedProfilePoint>[
      const EstimatedProfilePoint(0, 0),
      EstimatedProfilePoint(descent, maxDepth),
      if (ascentStart > descent) EstimatedProfilePoint(ascentStart, maxDepth),
      if (hasStop) ...[
        EstimatedProfilePoint(ascentStart + firstLeg, stopDepth),
        EstimatedProfilePoint(ascentStart + firstLeg + stop, stopDepth),
      ],
      EstimatedProfilePoint(end, 0),
    ];
    return EstimatedProfile._(List.unmodifiable(points));
  }

  static double? _positiveSeconds(Duration? duration) {
    if (duration == null || duration <= Duration.zero) return null;
    return duration.inMilliseconds / 1000;
  }

  static double _secondsFor(double meters, double metersPerMinute) =>
      meters / metersPerMinute * 60;

  @override
  List<Object?> get props => [points];
}
