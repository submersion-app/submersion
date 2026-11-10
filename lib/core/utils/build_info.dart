/// When this build was made, for Settings > About (issue #4365).
///
/// The release pipelines stamp it with `--dart-define=BUILD_DATE=YYYY-MM-DD`,
/// the build machine's UTC calendar date. Local and debug builds pass nothing,
/// so they have no date. `test/architecture/release_builds_stamp_build_date_
/// test.dart` keeps every shipped release build passing the flag.
library;

/// The raw BUILD_DATE dart-define; empty on a build that did not pass it.
const String buildDateDefine = String.fromEnvironment('BUILD_DATE');

final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// The calendar day in [raw] (`YYYY-MM-DD`), or null when [raw] is empty, is
/// not exactly that shape, or names a day that does not exist.
///
/// The day comes back as local midnight so that formatting shows exactly the
/// stamped day; a UTC instant would shift a day for divers west of Greenwich.
DateTime? parseBuildDate(String raw) {
  final match = _isoDate.firstMatch(raw);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime rolls an impossible day over (Feb 30 becomes Mar 2); refuse it.
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// This build's date, or null for a build without a stamp.
DateTime? get appBuildDate => parseBuildDate(buildDateDefine);
