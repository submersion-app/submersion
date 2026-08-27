import 'dart:math' as math;

/// Rounds [target] up to a "nice" step (1/2/5 x 10^n). Returns 0 for
/// non-positive targets (no ticks).
double niceStep(double target) {
  if (target <= 0) return 0;
  final exp = (math.log(target) / math.ln10).floorToDouble();
  final magnitude = math.pow(10.0, exp).toDouble();
  final base = target / magnitude;
  final double factor;
  if (base <= 1) {
    factor = 1;
  } else if (base <= 2) {
    factor = 2;
  } else if (base <= 5) {
    factor = 5;
  } else {
    factor = 10;
  }
  return factor * magnitude;
}

/// Tick text: whole numbers for whole steps, one decimal otherwise.
String formatTickValue(double value, double step) =>
    step % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
