/// Pure trend maths for the statistics charts: bucketing a per-dive series and
/// fitting curves through it. No I/O and no Flutter, so the statistical
/// behaviour is unit-testable in isolation (issue #299).
///
/// Every date here is a UTC-flagged wall clock, matching how `dive_date_time`
/// is stored and read. Bucket boundaries are built with `DateTime.utc` so the
/// machine's local offset can never shift a dive into a neighbouring bucket.
library;

/// Data point for line chart trends.
///
/// [label] is only used by the older index-axis `TrendLineChart`; per-dive
/// series leave it empty and format their axis from [date].
class TrendDataPoint {
  final DateTime date;
  final double value;
  final String label;

  /// The dive this point came from, when it came from exactly one. Null for a
  /// bucket, which stands for several dives, so nothing can be navigated to.
  final String? diveId;

  TrendDataPoint({
    required this.date,
    required this.value,
    this.label = '',
    this.diveId,
  });
}

/// How a per-dive series is folded before drawing. [none] is the default: one
/// drawn point per dive.
enum TrendAggregation { none, weekly, monthly }

/// One drawn point: a single dive under [TrendAggregation.none], or the dives
/// sharing a week or month otherwise.
class TrendBucket {
  const TrendBucket({
    required this.date,
    required this.mean,
    required this.min,
    required this.max,
    required this.count,
    this.diveId,
  });

  /// The dive behind a single-dive bucket, carried through so a raw point can
  /// be tapped. Null whenever the bucket folds more than one dive.
  final String? diveId;

  /// Start of the bucket, or the dive's own timestamp when not aggregating.
  final DateTime date;
  final double mean;
  final double min;
  final double max;
  final int count;
}

/// Folds [points] according to [mode], always returning buckets ordered by
/// date. Input order does not matter.
List<TrendBucket> aggregate(
  List<TrendDataPoint> points,
  TrendAggregation mode,
) {
  if (points.isEmpty) return const [];

  if (mode == TrendAggregation.none) {
    final ordered = [...points]..sort((a, b) => a.date.compareTo(b.date));
    return ordered
        .map(
          (p) => TrendBucket(
            date: p.date,
            mean: p.value,
            min: p.value,
            max: p.value,
            count: 1,
            diveId: p.diveId,
          ),
        )
        .toList(growable: false);
  }

  final grouped = <DateTime, List<double>>{};
  for (final point in points) {
    final key = _bucketStart(point.date, mode);
    grouped.putIfAbsent(key, () => <double>[]).add(point.value);
  }

  final keys = grouped.keys.toList()..sort();
  return keys
      .map((key) {
        final values = grouped[key]!;
        var sum = 0.0;
        var min = values.first;
        var max = values.first;
        for (final v in values) {
          sum += v;
          if (v < min) min = v;
          if (v > max) max = v;
        }
        return TrendBucket(
          date: key,
          mean: sum / values.length,
          min: min,
          max: max,
          count: values.length,
        );
      })
      .toList(growable: false);
}

DateTime _bucketStart(DateTime date, TrendAggregation mode) {
  switch (mode) {
    case TrendAggregation.monthly:
      return DateTime.utc(date.year, date.month);
    case TrendAggregation.weekly:
      final midnight = DateTime.utc(date.year, date.month, date.day);
      // DateTime.weekday is 1 for Monday through 7 for Sunday.
      return midnight.subtract(Duration(days: midnight.weekday - 1));
    case TrendAggregation.none:
      return date;
  }
}

/// Fewer points than this and neither fit is drawn: a confident line through
/// four dives says more than the data supports.
const int kMinTrendFitPoints = 5;

/// Centred mean over [window] neighbouring dives, ordered by date.
///
/// The window counts dives rather than calendar days on purpose. A time-based
/// window would compute some points from a liveaboard's forty dives and others
/// from none, so the line would be least stable exactly where the diving was
/// densest. At the ends the window truncates rather than padding.
///
/// Returns an empty list below [kMinTrendFitPoints].
List<TrendDataPoint> rollingMean(
  List<TrendDataPoint> points, {
  int window = 21,
}) {
  if (points.length < kMinTrendFitPoints) return const [];

  final ordered = [...points]..sort((a, b) => a.date.compareTo(b.date));
  final half = window ~/ 2;

  return List<TrendDataPoint>.generate(ordered.length, (i) {
    final lo = (i - half) < 0 ? 0 : i - half;
    final hi = (i + half + 1) > ordered.length ? ordered.length : i + half + 1;
    var sum = 0.0;
    for (var j = lo; j < hi; j++) {
      sum += ordered[j].value;
    }
    return TrendDataPoint(date: ordered[i].date, value: sum / (hi - lo));
  }, growable: false);
}

/// A least-squares line through a per-dive series, expressed against a fixed
/// [origin] so it can be evaluated at any date.
class LinearFit {
  const LinearFit({
    required this.origin,
    required this.slopePerDay,
    required this.intercept,
  });

  /// Date the fit is anchored to. [intercept] is the fitted value here.
  final DateTime origin;
  final double slopePerDay;
  final double intercept;

  /// The rate a diver can actually state, for example "+4.4 m per year".
  double get perYear => slopePerDay * 365.25;

  double valueAt(DateTime date) =>
      intercept +
      slopePerDay *
          (date.difference(origin).inSeconds / Duration.secondsPerDay);
}

/// Ordinary least squares over [points], with x measured in days since the
/// earliest point.
///
/// Returns null below [kMinTrendFitPoints], and null when every point shares a
/// single date (the slope would be undefined).
LinearFit? linearFit(List<TrendDataPoint> points) {
  if (points.length < kMinTrendFitPoints) return null;

  final ordered = [...points]..sort((a, b) => a.date.compareTo(b.date));
  final origin = ordered.first.date;

  final xs = ordered
      .map((p) => p.date.difference(origin).inSeconds / Duration.secondsPerDay)
      .toList(growable: false);
  final ys = ordered.map((p) => p.value).toList(growable: false);

  final n = xs.length;
  final meanX = xs.reduce((a, b) => a + b) / n;
  final meanY = ys.reduce((a, b) => a + b) / n;

  var numerator = 0.0;
  var denominator = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - meanX;
    numerator += dx * (ys[i] - meanY);
    denominator += dx * dx;
  }
  if (denominator == 0) return null;

  final slope = numerator / denominator;
  return LinearFit(
    origin: origin,
    slopePerDay: slope,
    intercept: meanY - slope * meanX,
  );
}
