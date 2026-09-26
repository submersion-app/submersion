import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A chart y-axis whose bounds and tick step are chosen together.
///
/// fl_chart spaces grid lines by `FlGridData.horizontalInterval` and side
/// titles by `SideTitles.interval`, and each independently falls back to its
/// own heuristic when left null. Deriving both from one [ChartAxis] is what
/// keeps a grid line under every label: fl_chart walks both sequences from
/// the same zero baseline, so an identical interval over bounds that are
/// whole multiples of it yields identical tick values.
@immutable
class ChartAxis {
  const ChartAxis({
    required this.min,
    required this.max,
    required this.interval,
  });

  /// Lower bound of the axis. Always a whole multiple of [interval].
  final double min;

  /// Upper bound of the axis. Always a whole multiple of [interval].
  final double max;

  /// Spacing between ticks. Feed this to both the grid and the side titles.
  final double interval;

  /// Builds an axis covering [values] with about a tenth of the span as
  /// headroom at each end, then widened to whole [interval] steps.
  ///
  /// An all-positive series never gets a negative axis, so a chart of rates
  /// or depths does not sprout a meaningless sub-zero band.
  factory ChartAxis.forTrend(Iterable<double> values, {int targetTicks = 4}) {
    final points = values.toList(growable: false);
    if (points.isEmpty) {
      return _snapped(0, 1, targetTicks: targetTicks, wholeSteps: false);
    }

    final lowest = points.reduce(math.min);
    final highest = points.reduce(math.max);
    final span = highest - lowest;
    // A flat series has no span of its own but still needs a band to draw in.
    final effectiveSpan = span > 0
        ? span
        : (highest.abs() > 0 ? highest.abs() * 0.2 : 1.0);
    final headroom = effectiveSpan * 0.1;

    return _snapped(
      lowest >= 0 ? math.max(0.0, lowest - headroom) : lowest - headroom,
      highest + headroom,
      targetTicks: targetTicks,
      wholeSteps: false,
    );
  }

  /// Builds an axis for a bar chart of counts: anchored at zero and stepping
  /// in whole units, since a count of 2.5 dives is not a thing to label.
  factory ChartAxis.forCounts(double maxCount, {int targetTicks = 4}) {
    return _snapped(
      0,
      maxCount > 0 ? maxCount * 1.1 : 1.0,
      targetTicks: targetTicks,
      wholeSteps: true,
    );
  }

  /// Nice-number steps within one order of magnitude. Counts skip 2.5.
  static const _fractionalSteps = <double>[1, 2, 2.5, 5, 10];
  static const _wholeSteps = <double>[1, 2, 5, 10];

  /// Widening [lower]/[upper] onto tick boundaries can add up to two extra
  /// segments; beyond that the axis is crowded and the step moves up a rung.
  static const _extraSegmentBudget = 2;

  static ChartAxis _snapped(
    double lower,
    double upper, {
    required int targetTicks,
    required bool wholeSteps,
  }) {
    var interval = _niceInterval(
      (upper - lower) / targetTicks,
      wholeSteps: wholeSteps,
    );
    var min = _floorTo(lower, interval);
    var max = _ceilTo(upper, interval);

    while ((max - min) / interval > targetTicks + _extraSegmentBudget) {
      final wider = _nextStepUp(interval, wholeSteps: wholeSteps);
      if (wider <= interval) break;
      interval = wider;
      min = _floorTo(lower, interval);
      max = _ceilTo(upper, interval);
    }

    return ChartAxis(
      min: min,
      max: max > min ? max : min + interval,
      interval: interval,
    );
  }

  /// Rounds [rough] to the nearest 1, 2, (2.5,) 5 or 10 times a power of ten.
  static double _niceInterval(double rough, {required bool wholeSteps}) {
    if (!rough.isFinite || rough <= 0) return 1;

    final magnitude = _magnitudeOf(rough);
    final normalized = rough / magnitude;
    final steps = wholeSteps ? _wholeSteps : _fractionalSteps;
    final step = steps.reduce(
      (a, b) => (normalized - a).abs() <= (normalized - b).abs() ? a : b,
    );
    final interval = step * magnitude;

    return wholeSteps ? math.max(1.0, interval.roundToDouble()) : interval;
  }

  static double _nextStepUp(double interval, {required bool wholeSteps}) {
    final magnitude = _magnitudeOf(interval);
    final normalized = interval / magnitude;
    final steps = wholeSteps ? _wholeSteps : _fractionalSteps;
    // _magnitudeOf floors the exponent, so normalized is in [1, 10) and the
    // trailing 10 in both ladders always matches. A throw here would mean that
    // invariant broke, which is worth hearing about rather than papering over.
    return steps.firstWhere((step) => step > normalized * (1 + _epsilon)) *
        magnitude;
  }

  /// The largest power of ten not exceeding [value], so that
  /// `value / _magnitudeOf(value)` always lands inside `[1, 10)`.
  ///
  /// The floor of `log(value) / ln10` is not enough on its own: for some exact
  /// powers of ten the division comes back a few ULPs short of the whole
  /// number (`log(1000) / ln10` is 2.9999999999999996, likewise at 1e6 and
  /// 1e9), which floors one exponent too low and pushes the normalized value
  /// to exactly 10. The correction restores the range the callers rely on.
  static double _magnitudeOf(double value) {
    if (!value.isFinite || value <= 0) return 1;

    final magnitude = math
        .pow(10, (math.log(value) / math.ln10).floor())
        .toDouble();
    if (value / magnitude >= 10) return magnitude * 10;
    if (value / magnitude < 1) return magnitude / 10;
    return magnitude;
  }

  /// Relative slack so a value already sitting on a tick is not pushed a whole
  /// step outward by binary-fraction error (14.7 / 0.1 is 146.99999999999997).
  static const _epsilon = 1e-9;

  static double _floorTo(double value, double interval) =>
      (value / interval + _epsilon).floorToDouble() * interval;

  static double _ceilTo(double value, double interval) =>
      (value / interval - _epsilon).ceilToDouble() * interval;
}
