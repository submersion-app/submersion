/// The clock a dive's photos and videos are placed against (issue #4539).
///
/// A capture time becomes a moment in the dive by counting from [start], the
/// instant the profile's first second stands for, after [offsetSeconds]
/// corrects the camera's clock.
class DiveMediaClock {
  const DiveMediaClock({required this.start, this.offsetSeconds = 0});

  /// The clock of a dive that starts at [diveStart], whose primary computer
  /// began recording at [primarySourceEntry].
  ///
  /// The profile's samples count from the computer's entry, so that is the
  /// instant wanted. The dive's own start is the diver's to move (a clock an
  /// hour out, a wrong date), which makes its hour and minute the ones to
  /// trust; what it can lack is the seconds, because a log file or the edit
  /// form holds whole minutes. A whole-minute start therefore takes the
  /// computer's instant when the two are under a minute apart, and otherwise
  /// keeps its own hour and minute with the computer's seconds.
  factory DiveMediaClock.of({
    required DateTime diveStart,
    required DateTime? primarySourceEntry,
    int offsetSeconds = 0,
  }) => DiveMediaClock(
    start: _startFor(diveStart, primarySourceEntry),
    offsetSeconds: offsetSeconds,
  );

  /// The instant the dive's profile counts from.
  final DateTime start;

  /// Seconds added to a capture time before it is placed: negative for a
  /// camera running ahead of the dive computer, positive for one behind.
  final int offsetSeconds;

  /// [captureTime] as the dive computer's clock would have read it.
  DateTime onDiveClock(DateTime captureTime) =>
      captureTime.add(Duration(seconds: offsetSeconds));

  static DateTime _startFor(DateTime diveStart, DateTime? sourceEntry) {
    if (sourceEntry == null || !_isWholeMinute(diveStart)) return diveStart;
    final gap = sourceEntry.difference(diveStart);
    if (gap.abs() < const Duration(minutes: 1)) return diveStart.add(gap);
    final entry = sourceEntry.toUtc();
    return diveStart.add(
      Duration(
        seconds: entry.second,
        milliseconds: entry.millisecond,
        microseconds: entry.microsecond,
      ),
    );
  }

  static bool _isWholeMinute(DateTime time) =>
      time.second == 0 && time.millisecond == 0 && time.microsecond == 0;
}
