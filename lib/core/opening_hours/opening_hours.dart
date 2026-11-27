import 'package:equatable/equatable.dart';

/// When a place is open (issue #5073): a dive site's gate, and later a dive
/// center's counter (#4667). Pure data; how it is stored lives in
/// `opening_hours_codec.dart`, and whether it is open at a given moment in
/// `opening_status.dart`.
///
/// Every time is a wall-clock time at the place itself, in minutes after
/// its local midnight.

/// Minutes in a day; a range may close at exactly midnight (1440).
const int minutesPerDay = 1440;

/// One stretch of a day the place is open, `[opensAt, closesAt)`.
class TimeRange extends Equatable {
  /// Minutes after local midnight, 0 to 1439.
  final int opensAt;

  /// Minutes after local midnight, 1 to 1440, after [opensAt].
  final int closesAt;

  const TimeRange(this.opensAt, this.closesAt);

  bool get isValid =>
      opensAt >= 0 && opensAt < closesAt && closesAt <= minutesPerDay;

  TimeRange copyWith({int? opensAt, int? closesAt}) =>
      TimeRange(opensAt ?? this.opensAt, closesAt ?? this.closesAt);

  @override
  List<Object?> get props => [opensAt, closesAt];
}

enum DayHoursKind { closed, open24h, ranges }

/// What a place does on one weekday.
class DayHours extends Equatable {
  final DayHoursKind kind;

  /// Sorted by [TimeRange.opensAt]; empty unless [kind] is
  /// [DayHoursKind.ranges].
  final List<TimeRange> ranges;

  const DayHours.closed() : kind = DayHoursKind.closed, ranges = const [];

  const DayHours.open24h() : kind = DayHoursKind.open24h, ranges = const [];

  const DayHours._ranges(this.ranges) : kind = DayHoursKind.ranges;

  /// Open for [ranges], kept sorted; no ranges is closed.
  factory DayHours.ranges(List<TimeRange> ranges) {
    if (ranges.isEmpty) return const DayHours.closed();
    final sorted = [...ranges]..sort((a, b) => a.opensAt.compareTo(b.opensAt));
    return DayHours._ranges(List.unmodifiable(sorted));
  }

  bool get isClosed => kind == DayHoursKind.closed;

  /// A day of [kind] (this one's when null); [ranges] apply to a day of
  /// hours only, and default to this day's.
  DayHours copyWith({DayHoursKind? kind, List<TimeRange>? ranges}) =>
      switch (kind ?? this.kind) {
        DayHoursKind.closed => const DayHours.closed(),
        DayHoursKind.open24h => const DayHours.open24h(),
        DayHoursKind.ranges => DayHours.ranges(ranges ?? this.ranges),
      };

  @override
  List<Object?> get props => [kind, ranges];
}

/// A day of the year with no year: 29 February counts as a valid day.
class MonthDay extends Equatable implements Comparable<MonthDay> {
  final int month;
  final int day;

  const MonthDay(this.month, this.day);

  /// Whether this day exists in a leap year.
  bool get isValid =>
      month >= 1 &&
      month <= 12 &&
      day >= 1 &&
      day <= DateTime(2000, month + 1, 0).day;

  MonthDay copyWith({int? month, int? day}) =>
      MonthDay(month ?? this.month, day ?? this.day);

  /// This day in [date]'s order of the year.
  static MonthDay of(DateTime date) => MonthDay(date.month, date.day);

  @override
  int compareTo(MonthDay other) =>
      month != other.month ? month - other.month : day - other.day;

  @override
  List<Object?> get props => [month, day];
}

/// A stretch of every year, both ends inclusive. An [end] before [start]
/// wraps past New Year (1 Nov to 31 Mar).
class YearlyDateRange extends Equatable {
  final MonthDay start;
  final MonthDay end;

  const YearlyDateRange({required this.start, required this.end});

  bool get wraps => end.compareTo(start) < 0;

  bool contains(DateTime date) {
    final day = MonthDay.of(date);
    return wraps
        ? day.compareTo(start) >= 0 || day.compareTo(end) <= 0
        : day.compareTo(start) >= 0 && day.compareTo(end) <= 0;
  }

  /// Days covered in a leap year: how specific the season is.
  int get lengthInDays {
    int ordinal(MonthDay d) => DateTime.utc(
      2000,
      d.month,
      d.day,
    ).difference(DateTime.utc(2000)).inDays;
    final span = ordinal(end) - ordinal(start);
    return wraps ? span + 366 + 1 : span + 1;
  }

  YearlyDateRange copyWith({MonthDay? start, MonthDay? end}) =>
      YearlyDateRange(start: start ?? this.start, end: end ?? this.end);

  @override
  List<Object?> get props => [start, end];
}

/// One week of hours, optionally for one season of the year.
class OpeningSchedule extends Equatable {
  final String? name;

  /// Null applies all year.
  final YearlyDateRange? season;

  /// Keyed by `DateTime.monday` to `DateTime.sunday`; a missing day is
  /// closed.
  final Map<int, DayHours> days;

  const OpeningSchedule({this.name, this.season, this.days = const {}});

  DayHours dayHours(int weekday) => days[weekday] ?? const DayHours.closed();

  OpeningSchedule copyWith({
    String? name,
    bool clearName = false,
    YearlyDateRange? season,
    bool clearSeason = false,
    Map<int, DayHours>? days,
  }) => OpeningSchedule(
    name: clearName ? null : (name ?? this.name),
    season: clearSeason ? null : (season ?? this.season),
    days: days ?? this.days,
  );

  /// Compared day by day, so a closed day written out equals a missing one.
  @override
  List<Object?> get props => [
    name,
    season,
    for (var d = DateTime.monday; d <= DateTime.sunday; d++) dayHours(d),
  ];
}

/// A place's opening hours: always open, or a set of schedules, plus a note
/// for what a schedule cannot say.
class OpeningHours extends Equatable {
  /// Open around the clock; the [schedules] are kept but not shown.
  final bool alwaysOpen;
  final List<OpeningSchedule> schedules;
  final String? note;

  const OpeningHours({
    this.alwaysOpen = false,
    this.schedules = const [],
    this.note,
  });

  /// Nothing worth storing.
  bool get isEmpty =>
      !alwaysOpen && schedules.isEmpty && (note?.trim().isEmpty ?? true);

  OpeningHours copyWith({
    bool? alwaysOpen,
    List<OpeningSchedule>? schedules,
    String? note,
    bool clearNote = false,
  }) => OpeningHours(
    alwaysOpen: alwaysOpen ?? this.alwaysOpen,
    schedules: schedules ?? this.schedules,
    note: clearNote ? null : (note ?? this.note),
  );

  @override
  List<Object?> get props => [alwaysOpen, schedules, note];
}
