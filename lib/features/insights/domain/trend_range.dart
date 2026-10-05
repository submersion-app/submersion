import 'package:flutter/foundation.dart';

/// The visible-window choices a date chart's Range menu offers.
enum TrendRangePreset { all, years5, years2, year1, months6, months3, custom }

/// What a date chart shows of its data: everything, a preset span ending at
/// the latest dive, or a custom pair of dates.
///
/// Dates rather than fractions, so a custom window keeps meaning the same
/// days when the filter changes the data's span.
@immutable
class TrendRange {
  const TrendRange.preset(this.preset)
    : assert(preset != TrendRangePreset.custom),
      start = null,
      end = null;

  const TrendRange.custom(DateTime this.start, DateTime this.end)
    : preset = TrendRangePreset.custom;

  static const all = TrendRange.preset(TrendRangePreset.all);

  final TrendRangePreset preset;
  final DateTime? start;
  final DateTime? end;

  @override
  bool operator ==(Object other) =>
      other is TrendRange &&
      other.preset == preset &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(preset, start, end);
}

/// The fraction window (0..1 of [dataStart]..[dataEnd]) that [range] shows.
///
/// A preset ends at [dataEnd]. A window that would start before the data
/// starts at the data, and a window with no overlap at all shows everything.
({double start, double end}) trendRangeFractions(
  TrendRange range,
  DateTime dataStart,
  DateTime dataEnd,
) {
  const everything = (start: 0.0, end: 1.0);
  final fullMs =
      dataEnd.millisecondsSinceEpoch - dataStart.millisecondsSinceEpoch;
  if (fullMs <= 0) return everything;

  final DateTime from;
  final DateTime to;
  switch (range.preset) {
    case TrendRangePreset.all:
      return everything;
    case TrendRangePreset.custom:
      from = range.start!;
      to = range.end!;
    case TrendRangePreset.years5:
    case TrendRangePreset.years2:
    case TrendRangePreset.year1:
    case TrendRangePreset.months6:
    case TrendRangePreset.months3:
      to = dataEnd;
      from = _presetStart(range.preset, dataEnd);
  }

  double fraction(DateTime d) =>
      ((d.millisecondsSinceEpoch - dataStart.millisecondsSinceEpoch) / fullMs)
          .clamp(0.0, 1.0);
  final start = fraction(from);
  final end = fraction(to);
  return end <= start ? everything : (start: start, end: end);
}

DateTime _presetStart(TrendRangePreset preset, DateTime end) {
  final (years, months) = switch (preset) {
    TrendRangePreset.years5 => (5, 0),
    TrendRangePreset.years2 => (2, 0),
    TrendRangePreset.year1 => (1, 0),
    TrendRangePreset.months6 => (0, 6),
    TrendRangePreset.months3 => (0, 3),
    TrendRangePreset.all || TrendRangePreset.custom => (0, 0),
  };
  // DateTime.utc normalises a month below 1 into the previous year.
  return DateTime.utc(
    end.year - years,
    end.month - months,
    end.day,
    end.hour,
    end.minute,
    end.second,
  );
}
