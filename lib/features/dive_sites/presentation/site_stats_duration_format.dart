/// "Xh Ym" for durations of an hour or more, "Xmin" otherwise, or
/// [placeholder] when [seconds] is null or not positive (issue #1018/#1038: a
/// dive with neither runtime nor bottom time contributes nothing to the
/// duration aggregate).
///
/// Shared by the site statistics card and the site hero card so the two
/// agree on every figure they both show.
String formatSiteStatsDuration(String placeholder, int? seconds) {
  if (seconds == null || seconds <= 0) return placeholder;
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}min';
}
