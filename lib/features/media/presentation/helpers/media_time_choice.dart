/// What the diver decided in the Set-time dialog (issue #1090).
sealed class MediaTimeChoice {
  const MediaTimeChoice();
}

/// Pin the item to [elapsedSeconds] from the dive start.
class MediaTimePinned extends MediaTimeChoice {
  const MediaTimePinned(this.elapsedSeconds);

  final int elapsedSeconds;
}

/// Drop the pin so the position derives from the capture time again.
class MediaTimeReset extends MediaTimeChoice {
  const MediaTimeReset();
}

/// Move every photo and video on the dive, because the camera's clock
/// disagrees with the dive computer's (issue #4539). [shiftSeconds] is the
/// dive's whole shift from here on, not an amount added to the one it has.
class MediaTimeDiveShifted extends MediaTimeChoice {
  const MediaTimeDiveShifted(this.shiftSeconds);

  /// Seconds added to each capture time: negative for a camera running
  /// ahead of the dive computer.
  final int shiftSeconds;
}

/// Drop the dive's shift so its media sits by capture time again.
class MediaTimeDiveShiftRemoved extends MediaTimeChoice {
  const MediaTimeDiveShiftRemoved();
}
