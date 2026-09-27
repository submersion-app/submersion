import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Pure candidate lookup: which dives a route's recording window could
/// belong to, by time alone.
///
/// Mirrors `GpsTrackMatcher`'s own tolerance and inclusive-edge convention
/// so a diver sees the same "close enough in time" behaviour whether a
/// surface GPS track or an underwater route is being matched to a dive.
class NavTrackMatcher {
  const NavTrackMatcher._();

  /// Maximum distance in time between a route's recording window and a
  /// dive's own window for the two to be considered related. Matches
  /// `GpsTrackMatcher.toleranceSeconds`.
  static const int toleranceSeconds = 1800;

  /// The dives in [dives] whose own window overlaps
  /// `[routeStartSeconds, routeEndSeconds]` once that route window is
  /// extended by [toleranceSeconds] on both sides, ordered by the size of
  /// the overlap (largest first).
  ///
  /// A dive's window is `effectiveEntryTime` to `exitTime`, or
  /// `effectiveEntryTime` plus `runtime` when no exit time is stored, or a
  /// single instant at `effectiveEntryTime` when neither is available --
  /// which still matches a route recorded around that instant, just never
  /// contributes more than a graze of overlap.
  ///
  /// All timestamps are wall-clock-as-UTC epoch seconds, the convention
  /// both `dives.entryTime` and a parsed route's own samples use, so no
  /// zone arithmetic is needed here.
  static List<Dive> candidatesFor({
    required int routeStartSeconds,
    required int routeEndSeconds,
    required List<Dive> dives,
  }) {
    final toleratedStart = routeStartSeconds - toleranceSeconds;
    final toleratedEnd = routeEndSeconds + toleranceSeconds;

    final scored = <(Dive, int)>[];
    for (final dive in dives) {
      final diveStart = dive.effectiveEntryTime.millisecondsSinceEpoch ~/ 1000;
      final diveEnd = _diveEndSeconds(dive, diveStart);
      final overlap = _overlapSeconds(
        toleratedStart,
        toleratedEnd,
        diveStart,
        diveEnd,
      );
      if (overlap >= 0) scored.add((dive, overlap));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final s in scored) s.$1];
  }

  static int _diveEndSeconds(Dive dive, int diveStartSeconds) {
    final exit = dive.exitTime;
    if (exit != null) return exit.millisecondsSinceEpoch ~/ 1000;
    final runtime = dive.runtime;
    if (runtime != null) return diveStartSeconds + runtime.inSeconds;
    return diveStartSeconds;
  }

  static int _overlapSeconds(int aStart, int aEnd, int bStart, int bEnd) {
    final start = aStart > bStart ? aStart : bStart;
    final end = aEnd < bEnd ? aEnd : bEnd;
    return end - start;
  }
}
