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
