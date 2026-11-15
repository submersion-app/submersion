import 'dart:math' as math;

import 'package:submersion/features/dive_3d/domain/geometry/nice_step.dart';

/// Round weight marks in the units the diver reads, so a scale lands on
/// 5 kg or 10 lb rather than on a converted 4.5 kg.
///
/// Used by the Buoyancy card's balance ruler and its lead history chart.
class WeightAxis {
  /// Allows for rounding in a span or peak that sits exactly on a mark.
  static const double _tolerance = 1e-9;

  static const WeightAxis _empty = WeightAxis._([], 0);

  /// The marks, rising from zero, in display units. Empty when there is
  /// nothing to scale.
  final List<double> ticks;

  /// The decimals that show every mark exactly.
  final int decimals;

  const WeightAxis._(this.ticks, this.decimals);

  /// Marks that stay inside [span]: the top mark is at or under it. For a
  /// scale whose end is fixed, such as one half of the balance bar.
  factory WeightAxis.within(double span, {int maxIntervals = 4}) {
    if (!span.isFinite || span <= 0 || maxIntervals < 1) return _empty;
    final step = niceStep(span / maxIntervals);
    return _build(step, (span / step + _tolerance).floor());
  }

  /// Marks that reach [peak]: the top mark is at or over it. For a chart that
  /// grows to fit its tallest value.
  factory WeightAxis.covering(double peak, {int maxIntervals = 2}) {
    if (!peak.isFinite || peak <= 0 || maxIntervals < 1) return _empty;
    final step = niceStep(peak / maxIntervals);
    return _build(step, (peak / step - _tolerance).ceil());
  }

  static WeightAxis _build(double step, int intervals) => WeightAxis._([
    for (var i = 0; i <= intervals; i++) i * step,
  ], _decimalsOf(step));

  /// The highest mark.
  double get top => ticks.isEmpty ? 0 : ticks.last;

  static int _decimalsOf(double step) {
    for (var decimals = 0; decimals < 6; decimals++) {
      final scaled = step * math.pow(10, decimals);
      if ((scaled - scaled.round()).abs() < _tolerance * scaled) {
        return decimals;
      }
    }
    return 6;
  }
}
