/// Pure bottom-time computation shared by the Dive entity and the dive
/// computer repository.
///
/// Bottom time is defined as surface departure to the start of the final
/// ascent (US Navy / dive-table convention): the descent counts; stops
/// shallower than the threshold (safety stops, shallow deco) do not,
/// while a stop deeper than the threshold -- a deep stop -- still counts
/// (the accepted trade-off in the design spec). The start of the final
/// ascent is approximated as the last profile sample at or deeper than a
/// depth threshold, which makes multilevel dives (a deep excursion followed by a
/// long shallower tail) measure correctly -- the retired heuristic (time
/// at/above 85% of max depth) collapsed them to the deep segment only.
class BottomTimeCalculator {
  BottomTimeCalculator._();

  /// Depth (meters) below which a sample never marks the end of bottom
  /// time; keeps shallow safety stops (3-5 m) out of the bottom phase.
  static const double defaultAbsoluteFloorMeters = 6.0;

  /// Fraction of max depth used for the ascent threshold on deeper dives,
  /// so mid-depth multilevel tails still count as bottom.
  static const double defaultMaxDepthFraction = 0.33;

  /// Cap on the threshold as a fraction of max depth. Guarantees the
  /// deepest sample always qualifies; without it, dives shallower than the
  /// absolute floor could never produce a result.
  static const double defaultThresholdCapFraction = 0.85;

  /// Bottom time in seconds from (timestamp, depth) samples, or null when
  /// the profile is too small or degenerate. Samples need not be sorted;
  /// timestamps are seconds from dive start, depths are meters.
  static int? secondsFromSamples(
    List<({int timestamp, double depth})> samples, {
    double absoluteFloorMeters = defaultAbsoluteFloorMeters,
    double maxDepthFraction = defaultMaxDepthFraction,
    double thresholdCapFraction = defaultThresholdCapFraction,
  }) {
    if (samples.length < 3) return null;

    final sorted = [...samples]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    var maxDepth = 0.0;
    for (final sample in sorted) {
      if (sample.depth > maxDepth) maxDepth = sample.depth;
    }
    if (maxDepth <= 0) return null;

    var threshold = maxDepth * maxDepthFraction;
    if (threshold < absoluteFloorMeters) threshold = absoluteFloorMeters;
    final cap = maxDepth * thresholdCapFraction;
    if (threshold > cap) threshold = cap;

    int? ascentStart;
    for (var i = sorted.length - 1; i >= 0; i--) {
      if (sorted[i].depth >= threshold) {
        ascentStart = sorted[i].timestamp;
        break;
      }
    }
    if (ascentStart == null) return null;

    final bottomSeconds = ascentStart - sorted.first.timestamp;
    return bottomSeconds > 0 ? bottomSeconds : null;
  }
}
