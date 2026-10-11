/// Tick selection for a date-valued chart x axis.
///
/// The older `TrendLineChart` plots `FlSpot(index, value)`, so a three-month
/// gap and a three-week gap render identically. Per-dive series cannot do that
/// and stay honest, so they plot real timestamps and need ticks chosen from the
/// span rather than from the point count (issue #299).
///
/// Deliberately free of Flutter and Riverpod: the widget threads in the
/// diver's [DateFormatPreference], and this file only decides where ticks go.
///
/// Free of the ambient locale only where the reading order is ambiguous, which
/// is the numeric day label. The month and year labels still go through intl's
/// named constructors and so resolve against `Intl.defaultLocale`, which is
/// what makes "Mar" read as "mars" on a French UI. That is the intended split:
/// the preference owns the order, the locale owns the words.
library;

import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';

enum DateAxisGranularity { day, month, quarter, year }

class DateAxis {
  const DateAxis({
    required this.min,
    required this.max,
    required this.ticks,
    required this.granularity,
    required this.labelInterval,
    this.dateFormat = DateFormatPreference.mmmDYYYY,
    this.scale = TrendTimeScale.identity,
    this.axisPerPixel,
  });

  /// Maps axis positions back to dates; collapses long gaps (issue #3251).
  final TrendTimeScale scale;

  /// Axis units per pixel of plot, when the plot width is known. Lets a
  /// label keep clear of a break band by a pixel distance.
  final double? axisPerPixel;

  /// Half the width of a band's length label ("6y 7m"), in pixels, plus the
  /// gap kept between it and a date label.
  static const double breakLabelClearancePx = 26;

  /// Half the width of a date label of each granularity, in pixels.
  static const Map<DateAxisGranularity, double> _labelHalfWidthPx = {
    DateAxisGranularity.year: 16,
    DateAxisGranularity.quarter: 24,
    DateAxisGranularity.month: 24,
    DateAxisGranularity.day: 24,
  };

  /// Narrowest spacing, in pixels, between two labels of each granularity at
  /// the chart's bodySmall size: "2014" and "Mar '25" plus a gap.
  static const Map<DateAxisGranularity, double> _minLabelSpacingPx = {
    DateAxisGranularity.year: 44,
    DateAxisGranularity.quarter: 60,
    DateAxisGranularity.month: 60,
    DateAxisGranularity.day: 64,
  };

  /// Lower bound, as `millisecondsSinceEpoch`, for fl_chart's `minX`.
  final double min;

  /// Upper bound, as `millisecondsSinceEpoch`, for fl_chart's `maxX`.
  final double max;

  /// Tick positions, strictly increasing and always inside the bounds.
  final List<DateTime> ticks;

  final DateAxisGranularity granularity;

  /// The diver's date order, which only the day-granularity label reads: a
  /// numeric "10/8" is the one label here that is ambiguous (#1512).
  final DateFormatPreference dateFormat;

  /// Spacing, in milliseconds, to hand fl_chart as `SideTitles.interval`.
  ///
  /// fl_chart calls `getTitlesWidget` only at values it derives from this
  /// interval, so a label drawn by matching a nominated tick timestamp exactly
  /// would essentially never render. Deriving a uniform step from the tick
  /// count and formatting whatever value arrives is what actually puts labels
  /// on the axis (issue #299 smoke check).
  final double labelInterval;

  /// Whether a label should be drawn at [value].
  ///
  /// fl_chart draws a label at [max] on top of the ones it derives from
  /// [labelInterval], so the last derived label can land almost on top of it
  /// and the two render as one run of jammed text ("AprMay"). Suppress any
  /// derived label that crowds a bound; the bound's own label stands.
  bool showsLabelAt(double value) {
    if (value < min || value > max) return false;
    if (value == min || value == max) return true;
    final crowding = labelInterval * 0.6;
    return (max - value) >= crowding && (value - min) >= crowding;
  }

  /// The text to draw at [value], or null when nothing should be drawn.
  ///
  /// Beyond the bound-crowding rule, this drops a label that repeats the one
  /// in the preceding slot. The step is uniform but months and years are not,
  /// so it drifts off real calendar boundaries and two adjacent slots can land
  /// in the same month ("Sep Sep").
  ///
  /// [step] must be the spacing fl_chart actually applied
  /// (`TitleMeta.appliedInterval`), not the [labelInterval] we requested.
  /// fl_chart is free to use a different one, and comparing against a value it
  /// never drew silently defeats the check.
  String? labelFor(double value, {double? step}) {
    if (!showsLabelAt(value) || _crowdsBreak(value)) return null;

    final text = _format(_dateOf(value));

    // The previous slot is the last multiple of the step below [value], or
    // the lower bound when that falls outside the axis: fl_chart lays its
    // slots on multiples of the step, not from min, so the first derived
    // label can sit less than a step from the bound (without the clamp that
    // pair goes uncompared, which is how "Sep Sep" survived), and the label
    // at max sits less than a step from the last slot. A slot that draws
    // nothing, such as one inside a collapsed gap (issue #3251), is no
    // duplicate to drop against.
    final s = step ?? labelInterval;
    var previous = ((value / s - 1e-9).ceil() - 1) * s;
    if (previous < min) previous = min;
    if (previous < value && showsLabelAt(previous) && !_crowdsBreak(previous)) {
      if (_format(_dateOf(previous)) == text) return null;
    }
    return text;
  }

  DateTime _dateOf(double value) => scale.toDate(value);

  /// Whether a label at [value] would sit in a gap (where it would name a
  /// date with no dives) or overlap a band's length label, which is centred
  /// on the band.
  bool _crowdsBreak(double value) {
    if (scale.inGap(value)) return true;
    final perPx = axisPerPixel;
    if (perPx == null) return false;
    final reach =
        (breakLabelClearancePx + _labelHalfWidthPx[granularity]!) * perPx;
    for (final b in scale.breaks) {
      if ((value - (b.axisStart + b.axisEnd) / 2).abs() < reach) return true;
    }
    return false;
  }

  /// Every label carries its year. A bare "Oct" never says which October, and
  /// spelling the year out only where it changes left the axis looking ragged,
  /// with one long label among short ones.
  ///
  /// The year is abbreviated to two digits to keep labels narrow: a wide label
  /// is what crowds the axis and makes neighbours collide. The apostrophe form
  /// is not reordered per locale, which is the compromise a compact axis takes.
  String _format(DateTime date) {
    switch (granularity) {
      case DateAxisGranularity.year:
        return DateFormat.y().format(date);
      case DateAxisGranularity.quarter:
      case DateAxisGranularity.month:
        return "${DateFormat.MMM().format(date)} '${_shortYear(date)}";
      case DateAxisGranularity.day:
        return "${DateFormat(UnitFormatter.numericMonthDayPattern(dateFormat)).format(date)} '${_shortYear(date)}";
    }
  }

  static String _shortYear(DateTime date) =>
      (date.year % 100).toString().padLeft(2, '0');

  /// Chooses a granularity from the span, then walks ticks across it.
  ///
  /// A degenerate range (one dive, or several on one day) is widened to a day
  /// so fl_chart has a non-zero axis to draw.
  factory DateAxis.forRange(
    DateTime first,
    DateTime last, {
    DateFormatPreference dateFormat = DateFormatPreference.mmmDYYYY,
  }) => DateAxis.forAxisRange(
    first.millisecondsSinceEpoch.toDouble(),
    last.millisecondsSinceEpoch.toDouble(),
    dateFormat: dateFormat,
  );

  /// An axis over positions [min]..[max] under [scale].
  ///
  /// Granularity comes from the axis span, which for a collapsed scale is
  /// the time with dives in it, not the calendar span. With [plotWidth] the
  /// label step is widened until neighbouring labels cannot touch.
  factory DateAxis.forAxisRange(
    double min,
    double max, {
    TrendTimeScale scale = TrendTimeScale.identity,
    double? plotWidth,
    DateFormatPreference dateFormat = DateFormatPreference.mmmDYYYY,
  }) {
    final lo = min;
    final hi = max > min ? max : min + Duration.millisecondsPerDay;

    // Whole days, as Duration.inDays counted them before the axis took
    // positions rather than dates.
    final days = ((hi - lo) / Duration.millisecondsPerDay).floor();
    final granularity = days > 1095
        ? DateAxisGranularity.year
        : days > 365
        ? DateAxisGranularity.quarter
        : days > 60
        ? DateAxisGranularity.month
        : DateAxisGranularity.day;

    final start = scale.toDate(lo);
    final end = scale.toDate(hi);
    final candidates =
        granularity == DateAxisGranularity.day && !scale.isIdentity
        ? _dayTicksOnAxis(lo, hi, days, scale)
        : _ticksFor(start, end, granularity);
    var ticks = [
      for (final t in candidates)
        if (!scale.inGap(scale.toAxis(t))) t,
    ];
    if (ticks.isEmpty) ticks = [start];

    // The step comes from every candidate, gap ones included: dropping the
    // ticks a gap swallows must not widen the spacing of the rest.
    final steps = candidates.length > 1 ? candidates.length - 1 : 1;
    var interval = (hi - lo) / steps;
    final width = plotWidth;
    final hasWidth = width != null && width > 0;
    if (hasWidth) {
      final minInterval = (hi - lo) * _minLabelSpacingPx[granularity]! / width;
      if (minInterval > interval) interval = minInterval;
    }

    return DateAxis(
      min: lo,
      max: hi,
      ticks: List.unmodifiable(ticks),
      granularity: granularity,
      labelInterval: interval,
      dateFormat: dateFormat,
      scale: scale,
      axisPerPixel: hasWidth ? (hi - lo) / width : null,
    );
  }

  /// Day ticks for a collapsed axis, stepped through axis space so the step
  /// follows the [days] with dives in view rather than the calendar span,
  /// which can run to years across a gap and leave a single tick.
  static List<DateTime> _dayTicksOnAxis(
    double lo,
    double hi,
    int days,
    TrendTimeScale scale,
  ) {
    final stepMs =
        (days <= 5 ? 1 : (days / 5).ceil()) *
        Duration.millisecondsPerDay.toDouble();
    return [for (var x = lo; x <= hi; x += stepMs) scale.toDate(x)];
  }

  static List<DateTime> _ticksFor(
    DateTime start,
    DateTime end,
    DateAxisGranularity granularity,
  ) {
    final ticks = <DateTime>[];

    switch (granularity) {
      case DateAxisGranularity.year:
        for (var y = start.year; y <= end.year; y++) {
          final tick = DateTime.utc(y);
          if (!tick.isBefore(start) && !tick.isAfter(end)) ticks.add(tick);
        }
      case DateAxisGranularity.quarter:
        var cursor = DateTime.utc(start.year, ((start.month - 1) ~/ 3) * 3 + 1);
        while (!cursor.isAfter(end)) {
          if (!cursor.isBefore(start)) ticks.add(cursor);
          cursor = DateTime.utc(cursor.year, cursor.month + 3);
        }
      case DateAxisGranularity.month:
        var cursor = DateTime.utc(start.year, start.month);
        while (!cursor.isAfter(end)) {
          if (!cursor.isBefore(start)) ticks.add(cursor);
          cursor = DateTime.utc(cursor.year, cursor.month + 1);
        }
      case DateAxisGranularity.day:
        // Aim for about five labels rather than one per day.
        final span = end.difference(start).inDays;
        final step = span <= 5 ? 1 : (span / 5).ceil();
        var cursor = DateTime.utc(start.year, start.month, start.day);
        if (cursor.isBefore(start)) {
          cursor = cursor.add(const Duration(days: 1));
        }
        while (!cursor.isAfter(end)) {
          ticks.add(cursor);
          cursor = cursor.add(Duration(days: step));
        }
    }

    // A range narrower than one tick step would otherwise draw a bare axis.
    if (ticks.isEmpty) ticks.add(start);
    return List.unmodifiable(ticks);
  }
}
