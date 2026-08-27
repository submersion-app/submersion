/// Formats [seconds] from the dive start as `m:ss`, minutes unpadded so an
/// hour-plus dive reads `75:00` rather than rolling into hours. Shared by the
/// Set-time dialog's field and the viewer's elapsed chip (issue #1090), so
/// what the diver types is what they later see.
String formatElapsedMmSs(int seconds) {
  final sign = seconds < 0 ? '-' : '';
  final abs = seconds.abs();
  final minutes = abs ~/ 60;
  final secs = abs % 60;
  return '$sign$minutes:${secs.toString().padLeft(2, '0')}';
}

final _mmSs = RegExp(r'^(\d+)(?::([0-5]\d))?$');

/// Parses `m:ss`, `mm:ss` or bare minutes into seconds from the dive start.
///
/// Returns null for anything else, including a seconds field of 60 or more
/// and a leading sign: the dialog offers only moments inside the dive.
int? parseElapsedMmSs(String input) {
  final match = _mmSs.firstMatch(input.trim());
  if (match == null) return null;
  final minutes = int.parse(match.group(1)!);
  final seconds = int.parse(match.group(2) ?? '0');
  return minutes * 60 + seconds;
}
