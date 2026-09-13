/// One profile sample reduced to what curve comparison needs: an offset in
/// seconds from its own dive's start, and a depth in meters.
typedef OffsetDepthSample = ({int offsetSeconds, double depth});

/// How closely one profile's samples track another's over the window they
/// share, once both are placed on the same clock.
class ProfileOverlapMatch {
  const ProfileOverlapMatch({
    required this.coverage,
    required this.meanAbsDepthErrorMeters,
    required this.comparedSamples,
  });

  /// Fraction (0-1) of the shorter profile's own samples that land inside
  /// the other profile's covered time span, so a match against only the
  /// first few seconds of a long dive still requires depth agreement over
  /// (nearly) the whole shorter segment, not just wherever the two happen
  /// to overlap.
  final double coverage;

  /// Mean absolute depth difference, in meters, between the shorter
  /// profile's samples and the other profile's depth (linearly
  /// interpolated) at the same clock offset, over the samples counted in
  /// [coverage].
  final double meanAbsDepthErrorMeters;

  /// How many samples the error was averaged over. Callers should treat a
  /// small count as low-confidence regardless of the other two fields.
  final int comparedSamples;

  /// A conservative bar for "this is the same recorded dive, not a
  /// coincidence": almost every sample of the shorter profile has to land
  /// inside the other one's span, and depth has to track it tightly. Two
  /// unrelated dives at a similar site essentially never hold both at once
  /// over an entire segment -- a shared depth trend for a few samples does
  /// not survive minute-by-minute comparison.
  bool get isStrongMatch =>
      comparedSamples >= 4 && coverage >= 0.9 && meanAbsDepthErrorMeters <= 1.0;
}

/// Depth at [offsetSeconds] on [sorted]'s own clock, linearly interpolated
/// between the bracketing samples. Null outside the covered range (before
/// the first sample or after the last) -- extrapolation is not attempted, so
/// a probe past either end must count as "not covered", never a guess.
///
/// [sorted] must already be sorted by `offsetSeconds`; callers with more
/// than a couple of comparisons should sort once and reuse the list, which
/// is why sorting is not repeated here.
double? _interpolatedDepth(List<OffsetDepthSample> sorted, int offsetSeconds) {
  if (sorted.isEmpty) return null;
  if (offsetSeconds < sorted.first.offsetSeconds ||
      offsetSeconds > sorted.last.offsetSeconds) {
    return null;
  }
  // Linear scan: profiles here are one dive's worth of samples (hundreds,
  // not thousands), and this runs per candidate pair during duplicate
  // detection, not in a hot per-frame loop.
  for (var i = 0; i < sorted.length - 1; i++) {
    final a = sorted[i];
    final b = sorted[i + 1];
    if (offsetSeconds < a.offsetSeconds || offsetSeconds > b.offsetSeconds) {
      continue;
    }
    if (b.offsetSeconds == a.offsetSeconds) return a.depth;
    final t =
        (offsetSeconds - a.offsetSeconds) / (b.offsetSeconds - a.offsetSeconds);
    return a.depth + (b.depth - a.depth) * t;
  }
  return sorted.last.depth;
}

/// Compares [incoming] against [existing] once both are placed on
/// [existing]'s clock: [incomingOffsetSeconds] is incoming's own sample-zero
/// time minus existing's, so a positive value means incoming started after
/// existing.
///
/// Returns null when there are too few candidate samples to judge --
/// [existing] or [incoming] has under two points, or fewer than
/// [minOverlapSamples] of incoming's samples fall inside existing's covered
/// span at all. A null result is "no evidence either way", not "no match";
/// callers should not treat it as a match themselves.
ProfileOverlapMatch? compareProfileOverlap({
  required List<OffsetDepthSample> existing,
  required List<OffsetDepthSample> incoming,
  required int incomingOffsetSeconds,
  int minOverlapSamples = 4,
}) {
  if (existing.length < 2 || incoming.length < 2) return null;

  final sortedExisting = [...existing]
    ..sort((a, b) => a.offsetSeconds.compareTo(b.offsetSeconds));

  var comparedSamples = 0;
  var errorSum = 0.0;
  for (final sample in incoming) {
    final onExistingClock = sample.offsetSeconds + incomingOffsetSeconds;
    final existingDepth = _interpolatedDepth(sortedExisting, onExistingClock);
    if (existingDepth == null) continue;
    comparedSamples++;
    errorSum += (sample.depth - existingDepth).abs();
  }

  if (comparedSamples < minOverlapSamples) return null;

  return ProfileOverlapMatch(
    coverage: comparedSamples / incoming.length,
    meanAbsDepthErrorMeters: errorSum / comparedSamples,
    comparedSamples: comparedSamples,
  );
}
