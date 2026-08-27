/// Repairs implausible single-sample depth readings before a recorded profile
/// is analyzed.
///
/// A dive computer occasionally logs one corrupt depth. The ascent-rate
/// calculator smooths rates with a centered moving average, which does not
/// remove such a sample -- it spreads it across the whole smoothing window and
/// turns one bad reading into a large, long-lived "ascent" that never
/// happened. Because the average is centered, half of that smear lands
/// *before* the bad sample, which is how a rapid-ascent warning surfaces in
/// the middle of a descent.
library;

/// Fastest vertical speed a diver can plausibly sustain, in m/min.
///
/// A runaway buoyant ascent tops out well under this; the fastest rate across
/// a real 40-dive logbook was 36 m/min. The bound exists to separate divers
/// from corrupt data, not to judge ascent technique -- that is the safety
/// review's job.
const double maxPlausibleRateMetersPerMin = 60.0;

/// Number of repair passes. Two passes catch a spike that is two samples wide;
/// anything longer is a sustained reading rather than a glitch.
const int _repairPasses = 2;

/// Returns [depths] with single-sample outliers replaced by the linear
/// interpolation of their neighbours.
///
/// A sample is an outlier only when the profile jumps away from it and
/// straight back: both the rate into it and the rate out of it exceed
/// [maxRateMetersPerMin] *and* they have opposite signs. A one-way jump is
/// left alone -- that is a sampling gap or a genuine descent, not a glitch.
///
/// The result always has the same length as [depths]. Analysis curves (NDL,
/// ceiling, ascent rates, tissue state) are index-aligned with the profile
/// samples by their consumers, so a sanitizer that dropped samples would
/// silently misalign every overlay on the dive profile chart.
List<double> repairDepthOutliers(
  List<double> depths,
  List<int> timestamps, {
  double maxRateMetersPerMin = maxPlausibleRateMetersPerMin,
}) {
  if (depths.length < 3 || depths.length != timestamps.length) {
    return depths;
  }

  final repaired = List<double>.from(depths);
  for (var pass = 0; pass < _repairPasses; pass++) {
    var changed = false;
    for (var i = 1; i < repaired.length - 1; i++) {
      final into = _rate(
        repaired[i - 1],
        repaired[i],
        timestamps[i - 1],
        timestamps[i],
      );
      final outOf = _rate(
        repaired[i],
        repaired[i + 1],
        timestamps[i],
        timestamps[i + 1],
      );
      final isSpike =
          into.abs() > maxRateMetersPerMin &&
          outOf.abs() > maxRateMetersPerMin &&
          into.sign != outOf.sign;
      if (isSpike) {
        repaired[i] = (repaired[i - 1] + repaired[i + 1]) / 2.0;
        changed = true;
      }
    }
    if (!changed) break;
  }
  return repaired;
}

/// Descent rate in m/min between two samples; positive means getting deeper.
/// Duplicate timestamps carry no rate information, so they report zero rather
/// than dividing by zero.
double _rate(double depth1, double depth2, int time1, int time2) {
  if (time2 == time1) return 0.0;
  return (depth2 - depth1) / ((time2 - time1) / 60.0);
}
