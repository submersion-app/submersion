import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A profile chart's time axis, in seconds on the primary's timeline: from
/// the earliest sample of [profile] or of any of [others] (0 when none is
/// negative) to the latest.
///
/// A source placed before the primary started, by a computer switched on
/// first or by a wrong clock, has negative timestamps, and an axis pinned at
/// 0 clips them off the left edge without a sign (#4296). The max is 0 for
/// no samples at all.
({int min, int max}) profileTimeDomain(
  List<DiveProfilePoint> profile, [
  Iterable<List<DiveProfilePoint>> others = const [],
]) {
  var lo = 0;
  int? hi;
  void scan(List<DiveProfilePoint> points) {
    for (final p in points) {
      if (p.timestamp < lo) lo = p.timestamp;
      if (hi == null || p.timestamp > hi!) hi = p.timestamp;
    }
  }

  scan(profile);
  others.forEach(scan);
  return (min: lo, max: hi ?? 0);
}
