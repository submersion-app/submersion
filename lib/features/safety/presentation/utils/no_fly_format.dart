/// "14h 20m" style remaining-time label for a no-fly countdown, shared by the
/// safety hub and the dashboard alerts banner.
String formatNoFlyRemaining(Duration remaining) {
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes}m';
}
