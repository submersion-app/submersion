import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The clock a dive's photos and videos are placed against (issue #4539).
///
/// A capture time becomes a moment in the dive by counting from [start], the
/// instant the profile's first second stands for, after [offsetSeconds]
/// corrects the camera's clock. [countsFrom] is the two folded into the one
/// instant a capture time is measured from.
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
    // A shift past the bound came from a damaged row. Counting from it would
    // overflow, so the dive's media is placed unshifted.
    offsetSeconds: isValidOffset(offsetSeconds) ? offsetSeconds : 0,
  );

  /// The clock of [dive], whose primary computer began recording at
  /// [primarySourceEntry]. Every path that places media builds its clock
  /// here, so none can leave the dive's shift out.
  factory DiveMediaClock.forDive(
    Dive dive, {
    required DateTime? primarySourceEntry,
  }) => DiveMediaClock.of(
    diveStart: dive.effectiveEntryTime,
    primarySourceEntry: primarySourceEntry,
    offsetSeconds: dive.mediaTimeOffsetSeconds,
  );

  /// [diveTime], a moment on [dive]'s own clock, as the dive's camera reads
  /// it: the other way by the dive's shift.
  ///
  /// Media is matched to a dive on the clock it is later placed by. A camera
  /// running ahead stamps the dive's moments late, so the dive's window, as
  /// that camera wrote it, sits later by as much. Matched on the dive's own
  /// clock, media would be attached that the shift then places outside the
  /// dive, and the media the shift was set for would never be found.
  static DateTime onCameraClock(Dive dive, DateTime diveTime) {
    final shift = dive.mediaTimeOffsetSeconds;
    return isValidOffset(shift)
        ? diveTime.subtract(Duration(seconds: shift))
        : diveTime;
  }

  /// The largest shift a dive holds, either way: a century, which covers a
  /// camera reset to its factory date and keeps a corrupt value from
  /// overflowing the arithmetic it feeds.
  static const int maxOffsetSeconds = 100 * 366 * 24 * 60 * 60;

  /// Whether [seconds] is a shift a dive can hold. Compared both ways
  /// rather than by magnitude: the smallest integer has no positive twin.
  static bool isValidOffset(int seconds) =>
      seconds >= -maxOffsetSeconds && seconds <= maxOffsetSeconds;

  /// The instant the dive's profile counts from.
  final DateTime start;

  /// Seconds added to a capture time before it is placed: negative for a
  /// camera running ahead of the dive computer, positive for one behind.
  final int offsetSeconds;

  /// The instant a capture time is counted from: [start] moved the other
  /// way by the shift.
  ///
  /// The shift goes on the start, not on the capture time. A dive's start is
  /// a wall clock stamped UTC, where arithmetic is exact; a capture time can
  /// arrive as a local time, and moving one of those across a daylight-saving
  /// change moves its wall clock by an hour.
  DateTime get countsFrom => start.subtract(Duration(seconds: offsetSeconds));

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
