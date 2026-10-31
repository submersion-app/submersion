/// Finds a daylight-saving change in the test process's own timezone, so a
/// test can sit on one under any zone instead of pinning a date per zone.
///
/// The Test job runs in Australia/Sydney and the Timezone Tests job replays
/// listed files in America/New_York and Australia/Adelaide, whose changes
/// fall on different dates. A zone with no DST has nothing to find, so pair
/// this with [zoneHasNoDst].
library;

/// The first true instant, in UTC, in 2027 at which this zone's clocks change,
/// or null when they never do.
///
/// [forward] picks the direction: true for the spring change that loses a
/// local hour, false for the autumn one that repeats it.
DateTime? dstTransition({required bool forward}) {
  const step = Duration(minutes: 15);
  final end = DateTime.utc(2028);
  var previous = DateTime.utc(2027);
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
final bool zoneHasNoDst = dstTransition(forward: true) == null;
