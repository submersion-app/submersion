/// Binary-search + linear-interpolation lookup over a monotonically
/// increasing time series. Used by the readout panel, marker layout, and
/// scrub cursor against the FULL-resolution profile (geometry may be
/// decimated; readouts must not be).
class ProfileLookup {
  final List<double> times;

  ProfileLookup(this.times);

  double? interpolate(List<double?> values, double t) {
    if (times.isEmpty) return null;
    if (t <= times.first) return values.first;
    if (t >= times.last) return values.last;
    var lo = 0, hi = times.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (times[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = values[lo], b = values[hi];
    if (a == null || b == null) return null;
    final span = times[hi] - times[lo];
    if (span <= 0) return a;
    return a + (b - a) * ((t - times[lo]) / span);
  }
}
