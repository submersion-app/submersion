/// Recovers the seconds MacDive drops from a dive's start time (#2509).
///
/// MacDive stores the start (`ZRAWDATE`, and `<date>` in its XML export) to
/// the minute. The identifier it keeps beside it (`ZIDENTIFIER`,
/// `<identifier>`) is `YYYYMMDDHHMMSS-<serial>` for computers that report a
/// full start time, and still carries the seconds, on the computer's own
/// wall clock.
class MacDiveStartSeconds {
  const MacDiveStartSeconds._();

  /// Exactly fourteen digits, then the serial. Older computers (the Suunto
  /// Cobra, for one) write unpadded stamps such as `2015122911130-822199`,
  /// which cannot be split into fields reliably and so never match.
  static final RegExp _stamp = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})-',
  );

  /// Every time zone in use is a whole number of quarter hours from UTC, and
  /// none is more than 14 hours away.
  static const int _zoneStepSeconds = 15 * 60;
  static const int _maxZoneOffsetSeconds = 14 * 60 * 60;

  /// [start] with the seconds from [identifier] added back.
  ///
  /// [start] may be the absolute instant (SQLite) or the wall clock encoded
  /// as UTC (XML). The identifier is the wall clock, so it differs from the
  /// start by a zone offset plus the dropped seconds. The offset is a whole
  /// number of quarter hours, so the difference modulo 15 minutes is the
  /// seconds, and that needs no knowledge of the dive's zone.
  ///
  /// Returns [start] unchanged when it already has seconds, when the
  /// identifier is not a full timestamp, or when it names a moment no zone
  /// offset can explain.
  static DateTime restore(DateTime start, String? identifier) {
    if (start.second != 0 || start.millisecond != 0 || start.microsecond != 0) {
      return start;
    }
    final stamp = _parse(identifier);
    if (stamp == null) return start;

    final difference = stamp.difference(start).inSeconds;
    if (difference.abs() > _maxZoneOffsetSeconds + 59) return start;
    // Dart's % is never negative for a positive divisor, so a zone west of
    // UTC lands on the same seconds as one east of it.
    final seconds = difference % _zoneStepSeconds;
    if (seconds == 0 || seconds > 59) return start;
    return start.add(Duration(seconds: seconds));
  }

  static DateTime? _parse(String? identifier) {
    final match = identifier == null ? null : _stamp.firstMatch(identifier);
    if (match == null) return null;
    final fields = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    final stamp = DateTime.utc(
      fields[0],
      fields[1],
      fields[2],
      fields[3],
      fields[4],
      fields[5],
    );
    // DateTime rolls out-of-range fields over (month 13 becomes January),
    // so a stamp that does not read back field for field is not a date.
    final roundTrips =
        stamp.year == fields[0] &&
        stamp.month == fields[1] &&
        stamp.day == fields[2] &&
        stamp.hour == fields[3] &&
        stamp.minute == fields[4] &&
        stamp.second == fields[5];
    return roundTrips ? stamp : null;
  }
}
