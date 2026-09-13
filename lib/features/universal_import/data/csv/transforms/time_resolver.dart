import 'package:intl/intl.dart';

import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/date_order.dart';

/// Informal time tokens that indicate a time-of-day bucket rather than a
/// specific time.
const _informalTokens = {
  'am',
  'pm',
  'morning',
  'afternoon',
  'evening',
  'night',
};

/// Default hours to assign when multiple dives share the same date and the
/// same informal token. The list is cycled through as dives accumulate.
const _amDefaults = [9, 11, 12];
const _pmDefaults = [14, 16, 17];
const _nightDefaults = [19, 21, 22];
const _emptyDefaults = [12, 14, 16];

/// Resolved wall-clock time (no timezone attached).
///
/// Stores hour, minute, second exactly as they appeared in the source.
class ResolvedTime {
  final int hour;
  final int minute;
  final int second;

  const ResolvedTime(this.hour, this.minute, this.second);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:'
      '${second.toString().padLeft(2, '0')}';
}

/// Handles all time/date parsing for CSV import.
///
/// Core principle: dive times are wall-clock times at the dive site. We store
/// them as UTC-encoded wall-time so that "2:00 PM" in Honduras displays as
/// "2:00 PM" regardless of the user's timezone.
class TimeResolver {
  /// [clock] supplies "today" for the two-digit year pivot; tests pin it.
  const TimeResolver({DateTime Function() clock = DateTime.now})
    : _clock = clock;

  final DateTime Function() _clock;

  // ---------------------------------------------------------------------------
  // Ordered list of time formats to try (12-hour FIRST to fix #63).
  static final List<DateFormat> _timeFormats = [
    DateFormat('h:mm:ss a'), // "2:00:00 PM", "2:00:00 AM"
    DateFormat('hh:mm:ss a'), // "02:00:00 PM"
    DateFormat('h:mm a'), // "2:00 PM"
    DateFormat('hh:mm a'), // "02:00 PM"
    DateFormat('HH:mm:ss'), // "14:00:00"
    DateFormat('HH:mm'), // "14:30"
    DateFormat('H:mm'), // "9:17"
  ];

  // ---------------------------------------------------------------------------
  // Numeric dates are matched by hand rather than with intl patterns: a `yyyy`
  // field accepts "91" and keeps it as the year 91 (#1829), and the day/month
  // order has to come from the caller rather than from pattern order (#1828).

  /// `yyyy-MM-dd`, `yyyy/M/d` and the like; the separators must match.
  static final _yearFirstPattern = RegExp(
    r'^(\d{4})([./-])(\d{1,2})\2(\d{1,2})$',
  );

  /// Date and time halves of a combined value, split at the first space or T.
  static final _dateTimeSplit = RegExp(r'^(\S+?)(?:\s+|T)(\S.*)$');

  // ---------------------------------------------------------------------------
  /// Parse a time string and return a [ResolvedTime], or null if unparseable.
  ///
  /// Tries 12-hour formats first (fixes #63), then 24-hour, then ISO fallback.
  ResolvedTime? parseTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();

    for (final fmt in _timeFormats) {
      try {
        final dt = fmt.parseStrict(s);
        return ResolvedTime(dt.hour, dt.minute, dt.second);
      } on Exception {
        continue;
      }
    }

    // ISO 8601 fallback — extract the time component only.
    // We validate the raw string looks like a time before attempting this to
    // avoid DateTime.parse silently wrapping invalid values like "99:99".
    if (_looksLikeRawTime(s)) {
      try {
        final dt = DateTime.parse('1970-01-01T$s');
        // Double-check the parsed values round-trip to the same string
        // (DateTime.parse can silently overflow e.g. "99:99").
        final rt = ResolvedTime(dt.hour, dt.minute, dt.second);
        // Verify the hour/minute/second are plausible by re-parsing them.
        if (dt.year == 1970 && dt.month == 1 && dt.day == 1) {
          return rt;
        }
      } on Exception {
        // ignore
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  /// Parse a date string and return a UTC [DateTime] at midnight, or null.
  ///
  /// A year-last date such as `03/04/1991` is read in [order], which the CSV
  /// transformer decides for the whole column. If that reading is not a real
  /// date the other order is tried, so `15/04/1991` is never dropped just
  /// because the column was taken to be month first. Without an [order],
  /// slash dates are read month first and dotted or dashed dates day first,
  /// as they always were.
  ///
  /// A two-digit year is placed in the latest century that does not put it in
  /// a future year: in 2026, `26` is 2026 and `91` is 1991.
  DateTime? parseDate(String? raw, {DateOrder? order}) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();

    final yearFirst = _yearFirstPattern.firstMatch(s);
    if (yearFirst != null) {
      return _validDate(
        int.parse(yearFirst.group(1)!),
        int.parse(yearFirst.group(3)!),
        int.parse(yearFirst.group(4)!),
      );
    }

    final yearLast = matchYearLastDate(s);
    if (yearLast != null) return _parseYearLast(yearLast, order);

    // ISO 8601 fallback.
    try {
      final dt = DateTime.parse(s);
      return DateTime.utc(dt.year, dt.month, dt.day);
    } on Exception {
      // ignore
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  /// Combine separate date + time strings (or a single dateTime string) into a
  /// UTC-encoded wall-clock [DateTime].
  ///
  /// Parameters:
  /// - [dateStr] — date column value
  /// - [timeStr] — time column value (optional)
  /// - [dateTimeStr] — combined date+time column value (alternative to the two above)
  /// - [interpretation] — how to treat the time
  /// - [specificOffset] — used when [interpretation] is [TimeInterpretation.specificOffset]
  /// - [dateOrder]: day/month order for whichever date string is read (see
  ///   [parseDate])
  ///
  /// Returns null if neither a date nor a dateTime can be parsed.
  DateTime? combineDateTime({
    String? dateStr,
    String? timeStr,
    String? dateTimeStr,
    TimeInterpretation interpretation = TimeInterpretation.localWallClock,
    Duration? specificOffset,
    DateOrder? dateOrder,
  }) {
    if (dateTimeStr != null && dateTimeStr.trim().isNotEmpty) {
      return _parseDateTimeStr(
        dateTimeStr.trim(),
        interpretation,
        specificOffset,
        dateOrder,
      );
    }

    final date = parseDate(dateStr, order: dateOrder);
    if (date == null) return null;

    final time = (timeStr != null) ? parseTime(timeStr) : null;
    final hour = time?.hour ?? 12;
    final minute = time?.minute ?? 0;
    final second = time?.second ?? 0;

    return _applyInterpretation(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
      second,
      interpretation,
      specificOffset,
    );
  }

  // ---------------------------------------------------------------------------
  /// Pre-pass across all rows: resolve informal time tokens and empty time
  /// values by assigning incrementing default hours grouped by date.
  ///
  /// Mutates a **copy** of each row that needs resolution, setting:
  /// - `row['dateTime']` — the resolved [DateTime]
  /// - `row['_informalTime']` — `true`
  ///
  /// Rows with a parseable time value are returned unchanged, and so are rows
  /// whose date cannot be read: there is no day to put the default hour on,
  /// so they are left for the caller to skip and report.
  ///
  /// The [rows] are expected to have at minimum a `'date'` key and a `'time'`
  /// key (the actual CSV column names should be normalised before calling this
  /// method). [dateOrder] is passed to [parseDate].
  List<Map<String, dynamic>> resolveInformalTimes(
    List<Map<String, dynamic>> rows, {
    DateOrder? dateOrder,
  }) {
    // Counters per (date, bucket) pair so we can cycle through defaults.
    final counters = <String, int>{};

    return rows.map((row) {
      final rawTime = row['time'] as String?;
      if (!isInformalToken(rawTime)) return Map<String, dynamic>.from(row);

      final rawDate = row['date'] as String?;
      final date = parseDate(rawDate, order: dateOrder);
      if (date == null) return Map<String, dynamic>.from(row);

      final bucket = _bucketFor(rawTime);
      final counterKey = '${date.year}-${date.month}-${date.day}:$bucket';

      final count = counters[counterKey] ?? 0;
      counters[counterKey] = count + 1;

      final defaults = _defaultsForBucket(bucket);
      final hour = defaults[count % defaults.length];

      final resolved = DateTime.utc(date.year, date.month, date.day, hour);

      return Map<String, dynamic>.from(row)
        ..['dateTime'] = resolved
        ..['_informalTime'] = true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  /// Returns true if [raw] is an informal token (am/pm/morning/etc.) or is
  /// empty/null — i.e., it should be replaced with a default time.
  bool isInformalToken(String? raw) {
    if (raw == null || raw.trim().isEmpty) return true;
    return _informalTokens.contains(raw.trim().toLowerCase());
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Parse a combined date+time string, handling ISO 8601 with offset.
  DateTime? _parseDateTimeStr(
    String s,
    TimeInterpretation interpretation,
    Duration? specificOffset,
    DateOrder? dateOrder,
  ) {
    // Try ISO 8601 with timezone offset first. If the string contains an
    // offset (+/-hh:mm or Z), we extract the wall-clock time (the local time
    // at the dive site) and store it as UTC-encoded wall-time (fixes #60).
    if (_looksLikeIsoWithOffset(s)) {
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        // toLocal gives us the device-local time; instead we want the
        // wall-clock at the *source* offset. Parse the offset from the string
        // and compute the wall-clock directly.
        final wallClock = _extractWallClock(s, dt);
        if (wallClock != null) {
          return DateTime.utc(
            wallClock.year,
            wallClock.month,
            wallClock.day,
            wallClock.hour,
            wallClock.minute,
            wallClock.second,
          );
        }
      }
    }

    // A date and a time side by side ("15/04/1991 14:30", "1991-04-15
    // 2:00 PM"), each half read exactly as a separate column would be.
    final halves = _dateTimeSplit.firstMatch(s);
    if (halves != null) {
      final date = parseDate(halves.group(1), order: dateOrder);
      final time = parseTime(halves.group(2));
      if (date != null && time != null) {
        return _applyInterpretation(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
          time.second,
          interpretation,
          specificOffset,
        );
      }
    }

    // Pure ISO 8601 without offset (treat as wall-clock).
    try {
      final dt = DateTime.parse(s);
      return _applyInterpretation(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
        interpretation,
        specificOffset,
      );
    } on Exception {
      // ignore
    }

    return null;
  }

  /// Reads a year-last date in [order], trying the other order only if the
  /// first reading is not a real date.
  DateTime? _parseYearLast(YearLastDate date, DateOrder? order) {
    final year = date.year.length == 2
        ? _expandTwoDigitYear(int.parse(date.year))
        : int.parse(date.year);
    final preferred =
        order ??
        (date.separator == '/' ? DateOrder.monthFirst : DateOrder.dayFirst);

    DateTime? read(DateOrder o) => o == DateOrder.dayFirst
        ? _validDate(year, date.second, date.first)
        : _validDate(year, date.first, date.second);

    return read(preferred) ??
        read(
          preferred == DateOrder.dayFirst
              ? DateOrder.monthFirst
              : DateOrder.dayFirst,
        );
  }

  /// The latest year ending in [twoDigits] that is not in the future.
  int _expandTwoDigitYear(int twoDigits) {
    final thisYear = _clock().year;
    final candidate = thisYear - thisYear % 100 + twoDigits;
    return candidate > thisYear ? candidate - 100 : candidate;
  }

  /// A UTC midnight for the given parts, or null if they are not a real date
  /// (month 13, 30 February and so on).
  DateTime? _validDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return null;
    final date = DateTime.utc(year, month, day);
    return date.month == month && date.day == day ? date : null;
  }

  /// Apply timezone interpretation and return a UTC DateTime.
  ///
  /// For [TimeInterpretation.localWallClock] and [TimeInterpretation.utc] we
  /// store the time components directly as UTC (wall-time convention). For
  /// [TimeInterpretation.specificOffset] we shift from the given offset to UTC.
  DateTime _applyInterpretation(
    int year,
    int month,
    int day,
    int hour,
    int minute,
    int second,
    TimeInterpretation interpretation,
    Duration? specificOffset,
  ) {
    switch (interpretation) {
      case TimeInterpretation.localWallClock:
      case TimeInterpretation.utc:
        // Store wall-clock components directly as UTC.
        return DateTime.utc(year, month, day, hour, minute, second);

      case TimeInterpretation.specificOffset:
        // Preserve wall-clock components as UTC (same convention as the other
        // cases). The offset is informational but the app stores wall-clock
        // time directly, so subtracting would produce wrong display values.
        return DateTime.utc(year, month, day, hour, minute, second);
    }
  }

  /// Check if [s] looks like an ISO 8601 string with an explicit timezone
  /// offset (e.g. "2023-07-15T09:17:19-04:00" or "...Z").
  bool _looksLikeIsoWithOffset(String s) {
    // Contains 'T' (date/time separator) AND ends with Z or +/-hh:mm.
    if (!s.contains('T')) return false;
    final trimmed = s.toUpperCase();
    if (trimmed.endsWith('Z')) return true;
    // Check for +hh:mm or -hh:mm at end.
    final offsetPattern = RegExp(r'[+\-]\d{2}:\d{2}$');
    return offsetPattern.hasMatch(s);
  }

  /// Extract the wall-clock DateTime from an ISO 8601 string with offset.
  ///
  /// Example: "2023-07-15T09:17:19-04:00" -> DateTime with hour=9, min=17, sec=19
  DateTime? _extractWallClock(String s, DateTime parsedUtc) {
    // Strategy: parse the offset from the string, then reconstruct wall-clock.
    // The offset is the last +/-hh:mm or Z in the string.
    if (s.toUpperCase().endsWith('Z')) {
      // UTC: wall-clock == UTC components.
      return parsedUtc;
    }

    final offsetPattern = RegExp(r'([+\-])(\d{2}):(\d{2})$');
    final match = offsetPattern.firstMatch(s);
    if (match == null) return null;

    final sign = match.group(1) == '+' ? 1 : -1;
    final offsetHours = int.parse(match.group(2)!);
    final offsetMinutes = int.parse(match.group(3)!);
    final offset = Duration(
      hours: sign * offsetHours,
      minutes: sign * offsetMinutes,
    );

    // wall-clock = UTC + offset
    final wallClock = parsedUtc.add(offset);
    return wallClock;
  }

  /// Return true if [s] looks like a raw time string (hh:mm or hh:mm:ss) with
  /// values in range. Used to guard the ISO 8601 time fallback.
  bool _looksLikeRawTime(String s) {
    final pattern = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$');
    final match = pattern.firstMatch(s);
    if (match == null) return false;
    final h = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    final sec = match.group(3) != null ? int.tryParse(match.group(3)!) : 0;
    if (h == null || m == null || sec == null) return false;
    return h >= 0 && h <= 23 && m >= 0 && m <= 59 && sec >= 0 && sec <= 59;
  }

  /// Map informal token to a bucket name.
  String _bucketFor(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'empty';
    switch (raw.trim().toLowerCase()) {
      case 'am':
      case 'morning':
        return 'am';
      case 'pm':
      case 'afternoon':
        return 'pm';
      case 'night':
      case 'evening':
        return 'night';
      default:
        return 'empty';
    }
  }

  /// Return the default hour list for a given bucket.
  List<int> _defaultsForBucket(String bucket) {
    switch (bucket) {
      case 'am':
        return _amDefaults;
      case 'pm':
        return _pmDefaults;
      case 'night':
        return _nightDefaults;
      default:
        return _emptyDefaults;
    }
  }
}
