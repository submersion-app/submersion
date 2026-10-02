import 'package:intl/intl.dart';

/// Recovers the seconds MacDive drops from a dive's start time (#2509).
///
/// MacDive stores the start (`ZRAWDATE`, and `<date>` in its XML export) to
/// the minute. The identifier it keeps beside it (`ZIDENTIFIER`,
/// `<identifier>`) is `YYYYMMDDHHMMSS-<serial>` for computers that report a
/// full start time, and still carries the seconds, on the computer's own
/// wall clock.
class MacDiveStartSeconds {
  const MacDiveStartSeconds._();

  /// Exactly fourteen digits, then the serial or the end. Older computers
  /// (the Suunto Cobra, for one) write unpadded stamps such as
  /// `2015122911130-822199`, which cannot be split into fields reliably and
  /// so never match.
  static final RegExp _stamp = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:-|$)',
  );

  /// intl cannot split abutting numeric fields (`yyyy` takes every digit),
  /// so the stamp's fields are joined with spaces before parsing. The stamp
  /// is ASCII whatever language the diver reads the app in, so the format
  /// is pinned to en_US, the one locale intl carries without
  /// initializeDateFormatting, rather than following `Intl.defaultLocale`.
  static final DateFormat _fields = DateFormat('yyyy MM dd HH mm ss', 'en_US');

  /// Every time zone in use is a whole number of quarter hours from UTC,
  /// between UTC-12 and UTC+14. Two wall clocks in different zones can
  /// therefore be up to 26 hours apart.
  static const int _zoneStepSeconds = 15 * 60;
  static const int _maxGapSeconds = 26 * 60 * 60;

  /// [start] with the seconds from [identifier] added back.
  ///
  /// [start] may be the absolute instant (SQLite) or the wall clock encoded
  /// as UTC (XML). The identifier is the computer's wall clock, so it
  /// differs from the start by a whole number of quarter hours (one zone
  /// offset for an instant, the gap between two zones for a wall clock)
  /// plus the dropped seconds. The difference modulo 15 minutes is
  /// therefore the seconds, and that needs no knowledge of either zone.
  ///
  /// Returns [start] unchanged when it already has seconds, when the
  /// identifier is not a full timestamp, or when the difference, less its
  /// seconds, is not a whole number of quarter hours within 26 hours. A
  /// stamp 15, 30 or 45 minutes from the start passes, since zones can be
  /// that close; only its seconds are taken, so the minute never moves.
  static DateTime restore(DateTime start, String? identifier) {
    if (start.second != 0 || start.millisecond != 0 || start.microsecond != 0) {
      return start;
    }
    final stamp = _parse(identifier);
    if (stamp == null) return start;

    final difference = stamp.difference(start).inSeconds;
    if (difference.abs() > _maxGapSeconds + 59) return start;
    // Dart's % is never negative for a positive divisor, so a zone west of
    // UTC lands on the same seconds as one east of it.
    final seconds = difference % _zoneStepSeconds;
    if (seconds == 0 || seconds > 59) return start;
    return start.add(Duration(seconds: seconds));
  }

  static DateTime? _parse(String? identifier) {
    final match = identifier == null ? null : _stamp.firstMatch(identifier);
    if (match == null) return null;
    final fields = [for (var i = 1; i <= 6; i++) match.group(i)!].join(' ');
    // parseStrict rejects fields DateTime would roll over (month 13, second
    // 75), so digits that are not a real date and time give no stamp.
    try {
      return _fields.parseStrict(fields, true);
    } on FormatException {
      return null;
    }
  }
}
