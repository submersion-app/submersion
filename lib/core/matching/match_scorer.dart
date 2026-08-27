/// Shared scoring primitives for fuzzy dive matching.
///
/// Both the file-import matcher (`DiveMatcher`) and the dive-computer download
/// matcher (`DiveComputerRepository.findMatchingDiveWithScore`) score a
/// candidate pair on time, depth, and duration, then combine the three with
/// weights. They differ only in their weights, breakpoints, units, and
/// missing-data handling — all of which are expressed as configuration here, so
/// the linear-falloff math lives in exactly one place.
library;

/// Linear-falloff sub-score in the range 0.0–1.0.
///
/// Returns 1.0 when [value] is at or below [full], 0.0 when at or above [zero],
/// and a straight-line interpolation in between. [zero] must be greater than or
/// equal to [full]; when they are equal the function degenerates to a step at
/// that point. [value] may be `double.infinity` to force a 0.0 score (used by
/// the percent-depth matcher when the existing depth is non-positive).
double bandScore(double value, {required double full, required double zero}) {
  if (value <= full) return 1.0;
  if (value >= zero) return 0.0;
  return 1.0 - ((value - full) / (zero - full));
}

/// A weighted match scorer parameterized by per-component weights and
/// [bandScore] breakpoints.
///
/// Callers compute each raw component *value* in the units that match this
/// scorer's breakpoints (e.g. minutes vs. milliseconds for time, a fraction vs.
/// meters for depth) and pass them to [score]; missing-data and guard handling
/// is done by the caller by choosing a sentinel value (0 to score 1.0 via a
/// `full: 0` band, `double.infinity` to score 0.0). This keeps the unit and
/// null semantics — which genuinely differ between the two matchers — at the
/// call site, while the falloff and weighting are shared.
class MatchScorer {
  /// Weight applied to the time sub-score (weights should sum to ~1.0).
  final double timeWeight;

  /// Weight applied to the depth sub-score.
  final double depthWeight;

  /// Weight applied to the duration sub-score.
  final double durationWeight;

  /// [bandScore] `full`/`zero` breakpoints for the time component.
  final double timeFull;
  final double timeZero;

  /// [bandScore] `full`/`zero` breakpoints for the depth component.
  final double depthFull;
  final double depthZero;

  /// [bandScore] `full`/`zero` breakpoints for the duration component.
  final double durationFull;
  final double durationZero;

  /// When true, a zero time sub-score short-circuits the whole score to 0.0.
  ///
  /// Time is then a NECESSARY condition: two recordings with no time overlap in
  /// evidence cannot be the same physical dive, so a depth + duration
  /// coincidence must not be able to reach the match threshold. The file-import
  /// matcher enables this; the download matcher does not (its SQL pre-filter
  /// already bounds candidates to the tolerance window).
  final bool gateOnZeroTime;

  const MatchScorer({
    required this.timeWeight,
    required this.depthWeight,
    required this.durationWeight,
    required this.timeFull,
    required this.timeZero,
    required this.depthFull,
    required this.depthZero,
    required this.durationFull,
    required this.durationZero,
    this.gateOnZeroTime = false,
  });

  /// Compute the weighted composite score for a candidate pair.
  ///
  /// Each `*Value` must already be expressed in the units of the corresponding
  /// breakpoints (see the class doc).
  double score({
    required double timeValue,
    required double depthValue,
    required double durationValue,
  }) {
    final timeScore = bandScore(timeValue, full: timeFull, zero: timeZero);
    if (gateOnZeroTime && timeScore <= 0) return 0.0;

    final depthScore = bandScore(depthValue, full: depthFull, zero: depthZero);
    final durationScore = bandScore(
      durationValue,
      full: durationFull,
      zero: durationZero,
    );

    return (timeScore * timeWeight) +
        (depthScore * depthWeight) +
        (durationScore * durationWeight);
  }
}
