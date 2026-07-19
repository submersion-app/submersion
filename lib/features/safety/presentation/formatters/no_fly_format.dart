/// Remaining-time label shared by the safety hub and the dashboard alerts
/// banner. Mirrors the app's duration convention (see
/// `dive_field_formatter.dart`): "Xh Ym" once there is at least an hour left,
/// "Ymin" for a minutes-only remainder.
String formatNoFlyRemaining(Duration remaining) {
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  if (hours == 0) {
    // A positive remainder under a minute floors to 0; show "<1min" rather
    // than a misleading "0min" while the restriction is still active.
    if (minutes == 0 && remaining > Duration.zero) return '<1min';
    return '${minutes}min';
  }
  return '${hours}h ${minutes}m';
}
