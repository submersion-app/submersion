import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';

/// When [dive] ended: its recorded exit time, else its start plus its
/// runtime. The same order as `DiveTimes.effectiveExitTime`, so an import
/// whose runtime and exit disagree ends where the rest of the app says.
DateTime diveEnd(Dive dive) =>
    dive.exitTime ??
    dive.effectiveEntryTime.add(dive.effectiveRuntime ?? Duration.zero);

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
          !dive.effectiveEntryTime.isAfter(followed.effectiveEntryTime))
        dive,
  ]..sort((a, b) => b.effectiveEntryTime.compareTo(a.effectiveEntryTime));

  final chain = [followed];
  for (final dive in earlier) {
    final gap = chain.last.effectiveEntryTime.difference(diveEnd(dive));
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
/// not in [pinned] that [sources] links to a logged tank (by id) starts at
/// that tank's end pressure, clamped at 0. Any other tank, or one whose
/// logged tank has no end pressure, keeps its own start pressure.
List<DiveTank> followedTankPressures(
  List<DiveTank> tanks,
  SeriesFollow follow, {
  Map<String, String> sources = const {},
  Set<String> pinned = const {},
}) {
  final ends = {for (final tank in follow.endTanks) tank.id: ?tank.endPressure};
  return [
    for (final tank in tanks)
      if (pinned.contains(tank.id))
        tank
      else if (ends[sources[tank.id]] case final end?)
        tank.copyWith(startPressure: end < 0 ? 0.0 : end)
      else if (follow.ownStartPressures[tank.id] case final own?)
        tank.copyWith(startPressure: own)
      else
        tank,
  ];
}
