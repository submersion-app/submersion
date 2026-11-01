import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';

/// When [dive] ended: its recorded exit time, else its start plus its
/// runtime. The same order as `DiveTimes.effectiveExitTime`, so an import
/// whose runtime and exit disagree ends where the rest of the app says.
DateTime diveEnd(Dive dive) =>
    dive.exitTime ??
    dive.effectiveEntryTime.add(dive.effectiveRuntime ?? Duration.zero);

/// [diveEnd] as a true instant, read in the device's zone, for measuring
/// elapsed time against now. Stored dive times are clock digits, so two of
/// them disagree with real time across a daylight saving change.
///
/// The start is converted before the runtime is added: added to clock digits,
/// a runtime that spans a change lands an hour from the real end.
DateTime diveEndInstant(Dive dive) {
  final exit = dive.exitTime;
  if (exit != null) return fromWallClockUtc(exit);
  return fromWallClockUtc(
    dive.effectiveEntryTime,
  ).add(dive.effectiveRuntime ?? Duration.zero);
}

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
/// at [end]: [defaultSeriesSurfaceInterval] when it ended less than that long
/// ago, so the plan starts that long after the dive; else the time since,
/// rounded up to the minute, so by default the plan starts now and never in
/// the past, however old the dive. The diver can still type a shorter one.
/// [end] and [now] are true instants; see [diveEndInstant].
Duration followSurfaceInterval(DateTime end, {required DateTime now}) {
  final elapsed = now.difference(end);
  if (elapsed < defaultSeriesSurfaceInterval) {
    return defaultSeriesSurfaceInterval;
  }
  return elapsedToTheMinute(end, now: now);
}

/// The time from [end] to [now], rounded up to the minute: what the Follow
/// prompt says and what following then sets, so the two agree.
Duration elapsedToTheMinute(DateTime end, {required DateTime now}) =>
    Duration(minutes: (now.difference(end).inSeconds + 59) ~/ 60);

/// Whether [a] and [b] are the same tank for carrying a pressure from one to
/// the other: the same size and gas.
bool sameCylinder(DiveTank a, DiveTank b) =>
    a.volume == b.volume &&
    a.workingPressure == b.workingPressure &&
    a.gasMix == b.gasMix;

/// [tanks] with what [follow] carries into the first planned dive: each tank
/// not in [pinned] that [sources] links to a logged tank (by id) starts at
/// that tank's end pressure, clamped at 0, while it is still that tank, the
/// same size and gas. One the diver has changed starts full, at its rated
/// pressure. Any other tank, or one whose logged tank has no end pressure,
/// keeps its own start pressure.
List<DiveTank> followedTankPressures(
  List<DiveTank> tanks,
  SeriesFollow follow, {
  Map<String, String> sources = const {},
  Set<String> pinned = const {},
}) {
  final logged = {for (final tank in follow.endTanks) tank.id: tank};
  return [
    for (final tank in tanks)
      if (pinned.contains(tank.id))
        tank
      else if (logged[sources[tank.id]] case final from?
          when !sameCylinder(from, tank))
        tank.copyWith(
          startPressure:
              tank.workingPressure ??
              follow.ownStartPressures[tank.id] ??
              tank.startPressure,
        )
      else if (logged[sources[tank.id]]?.endPressure case final end?)
        tank.copyWith(startPressure: end < 0 ? 0.0 : end)
      else if (follow.ownStartPressures[tank.id] case final own?)
        tank.copyWith(startPressure: own)
      else
        tank,
  ];
}
