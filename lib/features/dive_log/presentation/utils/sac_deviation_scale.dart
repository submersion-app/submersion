import 'dart:math' as math;

/// How the Gas consumption by segment chart lays each stretch of the dive out
/// against the dive's average rate: the average runs across the plot, and each
/// stretch rises above it or hangs below it by how far it strayed.
///
/// Both directions share one scale, so a bar reads true against any other.
/// The average sits where the largest swing each way needs it, within
/// [minBaseline] and [maxBaseline], so a dive that barely strayed one way
/// still leaves that side some room.
class SacDeviationScale {
  /// The highest the average runs, as a share of the plot from its top.
  static const double minBaseline = 0.2;

  /// The lowest the average runs, as a share of the plot from its top.
  static const double maxBaseline = 0.8;

  /// Where the average runs, as a share of the plot's height from its top.
  final double baseline;

  /// Each value's bar as a signed share of the plot's height: positive above
  /// the average, negative below it.
  final List<double> bars;

  /// The index of the value furthest above the average, or null when none
  /// rose above it.
  final int? highest;

  /// The index of the value furthest below the average, or null when none
  /// fell below it.
  final int? lowest;

  const SacDeviationScale._(
    this.baseline,
    this.bars,
    this.highest,
    this.lowest,
  );

  factory SacDeviationScale.of(List<double> values, {required double average}) {
    double deviation(double value) =>
        value.isFinite && average.isFinite ? value - average : 0;

    final deviations = [for (final value in values) deviation(value)];
    int? highest;
    int? lowest;
    for (final (index, d) in deviations.indexed) {
      if (d > 0 && (highest == null || d > deviations[highest])) {
        highest = index;
      }
      if (d < 0 && (lowest == null || d < deviations[lowest])) lowest = index;
    }

    final above = highest == null ? 0.0 : deviations[highest];
    final below = lowest == null ? 0.0 : -deviations[lowest];
    if (above + below <= 0) {
      return SacDeviationScale._(
        0.5,
        [for (final _ in values) 0.0],
        null,
        null,
      );
    }

    final baseline = (above / (above + below)).clamp(minBaseline, maxBaseline);
    final scale = math.min(
      above > 0 ? baseline / above : double.infinity,
      below > 0 ? (1 - baseline) / below : double.infinity,
    );
    return SacDeviationScale._(
      baseline,
      [for (final d in deviations) d * scale],
      highest,
      lowest,
    );
  }
}
