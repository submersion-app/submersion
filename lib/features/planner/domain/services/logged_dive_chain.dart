import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';

/// When [dive] started: its entry time, else its logged date and time.
DateTime diveStart(Dive dive) => dive.entryTime ?? dive.dateTime;

/// When [dive] ended: its start plus its runtime.
DateTime diveEnd(Dive dive) =>
    diveStart(dive).add(dive.effectiveRuntime ?? Duration.zero);

/// The logged dives a plan following [followedId] shows (issue #3565),
/// oldest first: the followed dive and the dives before it, back to the
/// first gap of [lookback] or more. Planned dives and dives logged after the
/// followed one are left out. Empty when [followedId] is not among [dives].
List<Dive> loggedDiveChain(
  List<Dive> dives,
  String followedId, {
  Duration lookback = followLookback,
}) {
  Dive? followed;
  for (final dive in dives) {
    if (dive.id == followedId) followed = dive;
  }
  if (followed == null) return const [];

  final earlier = [
    for (final dive in dives)
      if (dive.id != followedId &&
          !dive.isPlanned &&
          !diveStart(dive).isAfter(diveStart(followed)))
        dive,
  ]..sort((a, b) => diveStart(b).compareTo(diveStart(a)));

  final chain = [followed];
  for (final dive in earlier) {
    final gap = diveStart(chain.last).difference(diveEnd(dive));
    if (gap >= lookback) break;
    chain.add(dive);
  }
  return chain.reversed.toList();
}

/// The surface interval a plan starts with when it follows a dive that ended
/// at [end]: the time since, when the dive was recent, so the plan is for
/// now; else [defaultSeriesSurfaceInterval]. Under ten minutes reads as a
/// clock mismatch rather than a real interval, as it always has.
Duration followSurfaceInterval(DateTime end, {required DateTime now}) {
  final elapsed = now.difference(end);
  if (elapsed < const Duration(minutes: 10) || elapsed >= followLookback) {
    return defaultSeriesSurfaceInterval;
  }
  return Duration(minutes: elapsed.inMinutes);
}

/// [tanks] with what [follow] carries into the first planned dive: each tank
/// not in [pinned] starts at the end pressure of the first logged tank of
/// the same gas not already matched, clamped at 0. A tank with no match
/// keeps its own start pressure, from before it followed the dive.
List<DiveTank> followedTankPressures(
  List<DiveTank> tanks,
  SeriesFollow follow, {
  Set<String> pinned = const {},
}) {
  final used = <int>{};
  return [
    for (final tank in tanks)
      if (pinned.contains(tank.id))
        tank
      else
        () {
          for (var i = 0; i < follow.endTanks.length; i++) {
            final logged = follow.endTanks[i];
            final end = logged.endPressure;
            if (used.contains(i) || end == null) continue;
            if (!_sameGas(logged.gasMix, tank.gasMix)) continue;
            used.add(i);
            return tank.copyWith(startPressure: end < 0 ? 0.0 : end);
          }
          if (follow.ownStartPressures[tank.id] case final own?) {
            return tank.copyWith(startPressure: own);
          }
          return tank;
        }(),
  ];
}

bool _sameGas(GasMix a, GasMix b) =>
    a.roundedO2 == b.roundedO2 && a.roundedHe == b.roundedHe;
