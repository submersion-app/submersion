/// Finds a daylight-saving change in the test process's own timezone, so a
/// test can sit on one under any zone instead of pinning a date per zone.
///
/// The Test job runs in Australia/Sydney and the Timezone Tests job replays
/// listed files in America/New_York and Australia/Adelaide, whose changes
/// fall on different dates. A zone with no DST has nothing to find, so pair
/// this with [zoneHasNoDst].
library;

/// The first true instant, in UTC, at or after [from] at which this zone's
/// clocks change, or null within a year of [from] when they never do.
///
/// [forward] picks the direction: true for the spring change that loses a
/// local hour, false for the autumn one that repeats it.
DateTime? dstTransition({required bool forward, DateTime? from}) {
  const step = Duration(minutes: 15);
  final start = from?.toUtc() ?? DateTime.utc(2027);
  final end = start.add(const Duration(days: 366));
  var previous = start;
  var offset = previous.toLocal().timeZoneOffset;
  while (previous.isBefore(end)) {
    final next = previous.add(step);
    final nextOffset = next.toLocal().timeZoneOffset;
    if (nextOffset != offset && (nextOffset > offset) == forward) return next;
    previous = next;
    offset = nextOffset;
  }
  return null;
}

/// Whether this zone has no DST change to sit on, for a test's `skip:`: without
/// one, wall-clock and elapsed time cannot disagree.
bool get zoneHasNoDst => dstTransition(forward: true) == null;
