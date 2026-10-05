/// Splits a dive's OTU across a time window, so a dive that crosses a window
/// edge (usually midnight) counts only the part it accrued inside it.
///
/// Daily and weekly OTU limits are per calendar day: a 23:30 to 00:20 dive
/// belongs to both days, in proportion to when its oxygen exposure actually
/// happened, not to whichever day it started on.
class OtuWindowSplit {
  const OtuWindowSplit._();

  /// The part of [totalOtu] the dive accrued in `[from, to)`.
  ///
  /// [otuCurve] is the dive's cumulative OTU per profile sample and
  /// [curveTimestamps] each sample's seconds from [diveStart]. When the curve
  /// is usable the split follows it, scaled so the parts sum to [totalOtu]
  /// (the exposure total can come from the dive computer rather than the
  /// curve). Without one, OTU is assumed to accrue evenly over the dive.
  ///
  /// A dive with no duration counts in full in the window holding its start.
  static double otuWithin({
    required double totalOtu,
    required List<double>? otuCurve,
    required List<int>? curveTimestamps,
    required DateTime diveStart,
    required DateTime diveEnd,
    required DateTime from,
    required DateTime to,
  }) {
    if (totalOtu <= 0 || !to.isAfter(from)) return 0.0;
    double fractionBy(DateTime t) => _fractionAccruedBy(
      t,
      otuCurve: otuCurve,
      curveTimestamps: curveTimestamps,
      diveStart: diveStart,
      diveEnd: diveEnd,
    );
    return totalOtu * (fractionBy(to) - fractionBy(from));
  }

  /// Share of the dive's OTU accrued before [t], from 0 to 1.
  static double _fractionAccruedBy(
    DateTime t, {
    required List<double>? otuCurve,
    required List<int>? curveTimestamps,
    required DateTime diveStart,
    required DateTime diveEnd,
  }) {
    if (!t.isAfter(diveStart)) return 0.0;
    if (!t.isBefore(diveEnd)) return 1.0;

    final offsetSeconds = t.difference(diveStart).inMilliseconds / 1000.0;
    final curve = otuCurve;
    final times = curveTimestamps;
    if (curve != null &&
        times != null &&
        curve.length >= 2 &&
        curve.length == times.length &&
        curve.last > 0) {
      return (_cumulativeAt(curve, times, offsetSeconds) / curve.last).clamp(
        0.0,
        1.0,
      );
    }

    final span = diveEnd.difference(diveStart).inMilliseconds / 1000.0;
    return (offsetSeconds / span).clamp(0.0, 1.0);
  }

  /// [curve] linearly interpolated at [seconds].
  static double _cumulativeAt(
    List<double> curve,
    List<int> times,
    double seconds,
  ) {
    if (seconds <= times.first) return curve.first;
    for (var i = 1; i < times.length; i++) {
      if (seconds <= times[i]) {
        final t0 = times[i - 1];
        final t1 = times[i];
        if (t1 <= t0) return curve[i];
        final f = (seconds - t0) / (t1 - t0);
        return curve[i - 1] + (curve[i] - curve[i - 1]) * f;
      }
    }
    return curve.last;
  }
}
