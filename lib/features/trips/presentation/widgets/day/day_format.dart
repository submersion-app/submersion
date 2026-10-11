/// A day's time in the water as "1h 42m", or "45m" under an hour.
String formatDayRuntime(Duration runtime) => runtime.inHours > 0
    ? '${runtime.inHours}h ${runtime.inMinutes % 60}m'
    : '${runtime.inMinutes}m';
