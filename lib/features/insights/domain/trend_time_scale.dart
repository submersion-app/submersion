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
/// in milliseconds; each break is replaced by a band [bandFraction] of the
/// collapsed span wide, across which a date inside the gap maps
/// proportionally. The first period is never shifted, so a scale with no
/// breaks is exactly epoch milliseconds and a chart drawn through it is
/// unchanged.
class TrendTimeScale {
  const TrendTimeScale._(this.breaks, this._shifts);

  /// No breaks: `toAxis(d) == d.millisecondsSinceEpoch`.
  static const identity = TrendTimeScale._(<TrendGapBreak>[], <double>[0]);

  /// Share of the collapsed span (the sum of the periods) each band takes.
  static const double bandFraction = 0.03;

  /// A band is never narrower than this, so two dives years apart with
  /// nothing between them still draw a visible break.
  static const double _minBandMs = Duration.millisecondsPerDay * 1.0;

  /// Breaks in date order.
  final List<TrendGapBreak> breaks;

  /// Milliseconds subtracted from a date in period `i` to reach the axis.
  /// One more entry than [breaks].
  final List<double> _shifts;

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

    final breaks = <TrendGapBreak>[];
    final shifts = <double>[0];
    var shift = 0.0;
    for (final (start, end) in gaps) {
      final axisStart = start - shift;
      breaks.add(
        TrendGapBreak(
          start: _date(start),
          end: _date(end),
          axisStart: axisStart,
          axisEnd: axisStart + band,
        ),
      );
      shift += (end - start) - band;
      shifts.add(shift);
    }
    return TrendTimeScale._(
      List.unmodifiable(breaks),
      List.unmodifiable(shifts),
    );
  }

  /// [ms] plus [months] calendar months, on the UTC calendar. Instants, not
  /// wall-clock fields, so a local and a UTC date for the same moment agree.
  static int _addMonths(int ms, int months) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return DateTime.utc(
      d.year,
      d.month + months,
      d.day,
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
        return b.axisStart +
            (ms - start) / (end - start) * (b.axisEnd - b.axisStart);
      }
    }
    return ms - _shifts.last;
  }

  /// The date at x position [x], in UTC. Exact inside a period.
  DateTime toDate(double x) {
    for (var i = 0; i < breaks.length; i++) {
      final b = breaks[i];
      if (x <= b.axisStart) return _date(x + _shifts[i]);
      if (x < b.axisEnd) {
        final start = b.start.millisecondsSinceEpoch;
        final end = b.end.millisecondsSinceEpoch;
        return _date(
          start + (x - b.axisStart) / (b.axisEnd - b.axisStart) * (end - start),
        );
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
