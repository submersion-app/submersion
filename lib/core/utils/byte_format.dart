/// Formats a byte count for display.
///
/// Bytes are not a diver-facing unit, so this deliberately ignores the active
/// diver's unit settings: a megabyte is a megabyte in metric and imperial
/// alike. Sizes are a floor, since a source that reports no size counts zero.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}
