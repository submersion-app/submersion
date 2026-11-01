import 'dart:math' as math;

/// The rate scale of the Gas consumption by segment chart, in the units the
/// diver reads, so its lines land on round numbers in psi/min as in L/min.
class SacRateAxis {
  static const int _maxIntervals = 3;
  static const List<double> _steps = [1, 2, 2.5, 5, 10];

  /// Allows for rounding in a peak that sits exactly on a line.
  static const double _tolerance = 1e-9;

  /// The lines, rising from zero. Empty when there is nothing to scale.
  final List<double> ticks;

  /// The decimals that show every line exactly.
  final int decimals;

  const SacRateAxis._(this.ticks, this.decimals);

  factory SacRateAxis.forPeak(double peak) {
    if (!peak.isFinite || peak <= 0) return const SacRateAxis._([], 0);

    final exponent = (math.log(peak / _maxIntervals) / math.ln10).floor();
    final magnitude = math.pow(10.0, exponent).toDouble();
    final step = _steps
        .map((s) => s * magnitude)
        .firstWhere((s) => _intervals(peak, s) <= _maxIntervals);
    return SacRateAxis._([
      for (var i = 0; i <= _intervals(peak, step); i++) i * step,
    ], _decimalsOf(step));
  }

  /// The highest line, which every column stays at or under.
  double get top => ticks.isEmpty ? 0 : ticks.last;

  static int _intervals(double peak, double step) =>
      (peak / step - _tolerance).ceil();

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
