import 'dart:math' as math;

double meanOf(List<double> values) =>
    values.fold<double>(0, (sum, v) => sum + v) / values.length;

/// |mean(a) - mean(b)| over the pooled sample standard deviation (Cohen's
/// d). Null with fewer than two samples on either side. Infinite when
/// neither side varies but the means differ.
double? effectSize(List<double> a, List<double> b) {
  if (a.length < 2 || b.length < 2) return null;
  final ma = meanOf(a);
  final mb = meanOf(b);
  double squares(List<double> v, double m) =>
      v.fold<double>(0, (s, x) => s + (x - m) * (x - m));
  final pooled = math.sqrt(
    (squares(a, ma) + squares(b, mb)) / (a.length + b.length - 2),
  );
  final diff = (ma - mb).abs();
  if (pooled == 0) return diff == 0 ? 0 : double.infinity;
  return diff / pooled;
}
