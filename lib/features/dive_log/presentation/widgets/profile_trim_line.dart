import 'dart:math' as math;

/// Half the span of the trim axis for [values], in degrees: the largest
/// angle either side of flat, rounded up to the next 5 degrees, never less
/// than 10 so a well-trimmed dive is not drawn as a large swing, and never
/// past vertical (issue #5098).
double trimAxisHalfRange(Iterable<double> values) {
  final largest = values.fold<double>(0, (m, v) => math.max(m, v.abs()));
  final rounded = (largest / 5).ceil() * 5.0;
  return rounded.clamp(10.0, 90.0);
}

/// [degrees] as the chart shows a trim angle: whole degrees with a sign, so
/// head up (+) and head down (-) read at a glance; flat is '0°'.
String formatTrimDegrees(double degrees) {
  final whole = degrees.round();
  if (whole == 0) return '0°';
  return whole > 0 ? '+$whole°' : '$whole°';
}
