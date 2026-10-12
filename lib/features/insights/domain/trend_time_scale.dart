import 'dart:math' as math;

import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';

/// One collapsed stretch with no dives (issue #3251).
class TrendGapBreak {
  const TrendGapBreak({
    required this.start,
    required this.end,
    required this.axisStart,
    required this.axisEnd,
  });

  /// The last plotted date before the gap.
  final DateTime start;

  /// The first plotted date after it.
  final DateTime end;

  /// The band's left and right edges on the chart's x axis.
  final double axisStart;
  final double axisEnd;
}

/// Maps dates to a trend chart's x axis and back, collapsing every stretch
/// with no dives longer than a [TrendGapThreshold] into a narrow band.
///
/// Piecewise linear: inside a period of diving, axis distance is real time
/// in milliseconds; each gap is replaced by a region holding a hatched band
/// [bandFraction] of the collapsed span wide with a [marginFraction] margin
/// either side, and a date inside the gap maps proportionally across the
/// region. The margins keep the dives either side of a gap clear of the
/// band, and give a sparse logbook (every period a single dive) an axis that
/// is not all band. The first period is never shifted, so a scale with no
/// breaks is exactly epoch milliseconds and a chart drawn through it is
/// unchanged.
class TrendTimeScale {
  const TrendTimeScale._(this.breaks, this._shifts, this._regions);

  /// No breaks: `toAxis(d) == d.millisecondsSinceEpoch`.
  static const identity = TrendTimeScale._(<TrendGapBreak>[], <double>[
    0,
  ], <(double, double)>[]);

  /// Share of the collapsed span (the sum of the periods) each band takes.
  static const double bandFraction = 0.03;

  /// Share of the collapsed span left clear either side of each band.
  static const double marginFraction = 0.02;

  /// A band is never narrower than this.
  static const double _minBandMs = Duration.millisecondsPerDay * 1.0;

  /// A margin is never narrower than this, so two dives years apart with
  /// nothing between them still read as two dives and a break, not a band.
  static const double _minMarginMs = Duration.millisecondsPerDay * 7.0;

  /// Breaks in date order.
  final List<TrendGapBreak> breaks;

  /// Milliseconds subtracted from a date in period `i` to reach the axis.
  /// One more entry than [breaks].
  final List<double> _shifts;

  /// The axis span each gap maps onto: its band plus both margins.
  final List<(double, double)> _regions;

  bool get isIdentity => breaks.isEmpty;

  /// Builds the scale for [dates] (any order, duplicates allowed): every
  /// date the chart plots, so no plotted point can fall inside a band.
  factory TrendTimeScale.build(
    Iterable<DateTime> dates,
    TrendGapThreshold threshold,
  ) {
    if (threshold == TrendGapThreshold.off) return identity;
    final ms = dates.map((d) => d.millisecondsSinceEpoch).toSet().toList()
      ..sort();
    if (ms.length < 2) return identity;

    final gaps = <(int, int)>[];
    for (var i = 1; i < ms.length; i++) {
      final limit = _addMonths(ms[i - 1], threshold.months);
      if (ms[i] > limit) gaps.add((ms[i - 1], ms[i]));
    }
    if (gaps.isEmpty) return identity;

    final gapTotal = gaps.fold<int>(0, (sum, g) => sum + g.$2 - g.$1);
    final collapsed = (ms.last - ms.first - gapTotal).toDouble();
    final band = math.max(collapsed * bandFraction, _minBandMs);
    final margin = math.max(collapsed * marginFraction, _minMarginMs);

    final breaks = <TrendGapBreak>[];
    final regions = <(double, double)>[];
    final shifts = <double>[0];
    var shift = 0.0;
    for (final (start, end) in gaps) {
      final real = (end - start).toDouble();
      // A collapsed gap never takes more axis than the real one: on a long
      // logbook the band and margins can outgrow a gap just past the
      // threshold, so they shrink together to fit it.
      final fit = math.min(1.0, real / (band + 2 * margin));
      final regionStart = start - shift;
      final axisStart = regionStart + margin * fit;
      final axisEnd = axisStart + band * fit;
      final regionEnd = axisEnd + margin * fit;
      breaks.add(
        TrendGapBreak(
          start: _date(start),
          end: _date(end),
          axisStart: axisStart,
          axisEnd: axisEnd,
        ),
      );
      regions.add((regionStart, regionEnd));
      shift += real - (regionEnd - regionStart);
      shifts.add(shift);
    }
    return TrendTimeScale._(
      List.unmodifiable(breaks),
      List.unmodifiable(shifts),
      List.unmodifiable(regions),
    );
  }

  /// [ms] plus [months] calendar months, on the UTC calendar. Instants, not
  /// wall-clock fields, so a local and a UTC date for the same moment agree.
  static int _addMonths(int ms, int months) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    // Day 0 of the month after the target is the target's last day, so Aug
    // 31 plus six months clamps to Feb 28 instead of rolling into March.
    final lastDay = DateTime.utc(d.year, d.month + months + 1, 0).day;
    return DateTime.utc(
      d.year,
      d.month + months,
      d.day > lastDay ? lastDay : d.day,
      d.hour,
      d.minute,
      d.second,
      d.millisecond,
    ).millisecondsSinceEpoch;
  }

  static DateTime _date(num ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: true);

  /// The x position of [date].
  double toAxis(DateTime date) {
    final ms = date.millisecondsSinceEpoch.toDouble();
    for (var i = 0; i < breaks.length; i++) {
      final b = breaks[i];
      final start = b.start.millisecondsSinceEpoch;
      final end = b.end.millisecondsSinceEpoch;
      if (ms <= start) return ms - _shifts[i];
      if (ms < end) {
        final (from, to) = _regions[i];
        return from + (ms - start) / (end - start) * (to - from);
      }
    }
    return ms - _shifts.last;
  }

  /// The date at x position [x], in UTC. Exact inside a period.
  DateTime toDate(double x) {
    for (var i = 0; i < breaks.length; i++) {
      final b = breaks[i];
      final (from, to) = _regions[i];
      if (x <= from) return _date(x + _shifts[i]);
      if (x < to) {
        final start = b.start.millisecondsSinceEpoch;
        final end = b.end.millisecondsSinceEpoch;
        return _date(start + (x - from) / (to - from) * (end - start));
      }
    }
    return _date(x + _shifts.last);
  }

  /// The break whose band contains [x], or null.
  TrendGapBreak? breakAt(double x) {
    for (final b in breaks) {
      if (x > b.axisStart && x < b.axisEnd) return b;
    }
    return null;
  }

  /// Whether [x] lies inside a gap's region: its band or either margin,
  /// where no dive can be and no date label belongs.
  bool inGap(double x) {
    for (final (from, to) in _regions) {
      if (x > from && x < to) return true;
    }
    return false;
  }

  /// Which period [date] belongs to: 0 before the first break, and one more
  /// for each break that ends at or before it.
  int periodOf(DateTime date) {
    final ms = date.millisecondsSinceEpoch;
    var i = 0;
    while (i < breaks.length && breaks[i].end.millisecondsSinceEpoch <= ms) {
      i++;
    }
    return i;
  }
}
