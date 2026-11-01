import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/logged_dive_chain.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';

/// How long a dive's OTU counts towards a later dive: the daily limit.
const otuCarryWindow = Duration(hours: 24);

/// One dive of a series as computed: its inputs with everything the earlier
/// dives carry in applied, and the engine's outcome for them.
class SeriesDiveResult {
  final DivePlanState state;
  final PlanOutcome outcome;

  /// What the series itself raises about this dive (see [seriesIssuesFor]),
  /// also among [outcome]'s issues. Held apart for the live outcome, which the
  /// engine computes alone.
  final List<PlanIssue> seriesIssues;

  const SeriesDiveResult({
    required this.state,
    required this.outcome,
    this.seriesIssues = const [],
  });
}

/// A surface interval shorter than this is flagged.
const shortSurfaceIntervalLimit = Duration(minutes: 10);

/// How much deeper than the dive before counts as a reverse profile.
const reverseProfileMarginMeters = 12.0;

/// What the series raises about the dive at [index], whose inputs with its
/// carry applied are [state], from [earlier]: the dives before it, in order.
/// A first dive that follows nothing has no dive before it, so raises nothing.
List<PlanIssue> seriesIssuesFor(
  List<PlanSeriesDive> dives,
  int index,
  DivePlanState state,
  double maxDepth,
  List<SeriesDiveResult> earlier, {
  required PlanEngineConfig config,
  SeriesFollow? follow,
}) {
  if (index == 0 && follow == null) return const [];
  final issues = <PlanIssue>[];

  final end = previousEnd(index, earlier, follow: follow);
  final start = state.startDateTime;
  final overlap = end == null || start == null || !dives[index].fixedStart
      ? Duration.zero
      : end.difference(fromWallClockUtc(start));
  final interval = state.surfaceInterval;
  if (overlap > Duration.zero) {
    issues.add(
      PlanIssue(
        type: PlanIssueType.startsBeforePreviousEnds,
        severity: PlanIssueSeverity.critical,
        message: 'Starts before the previous dive ends',
        value: overlap.inMinutes.toDouble(),
      ),
    );
  } else if (interval != null && interval < shortSurfaceIntervalLimit) {
    issues.add(
      PlanIssue(
        type: PlanIssueType.shortSurfaceInterval,
        severity: PlanIssueSeverity.warning,
        message: 'Surface interval under the limit',
        value: interval.inMinutes.toDouble(),
        threshold: shortSurfaceIntervalLimit.inMinutes.toDouble(),
      ),
    );
  }

  if (startsOwingDeco(state, config: config)) {
    issues.add(
      const PlanIssue(
        type: PlanIssueType.startsOwingDeco,
        severity: PlanIssueSeverity.critical,
        message: 'Starts with a deco obligation',
      ),
    );
  }

  final previousDepth = index == 0
      ? follow?.followed.maxDepth
      : earlier[index - 1].outcome.maxDepth;
  if (previousDepth != null &&
      maxDepth > previousDepth + reverseProfileMarginMeters) {
    issues.add(
      PlanIssue(
        type: PlanIssueType.reverseProfile,
        severity: PlanIssueSeverity.warning,
        message: 'Deeper than the dive before',
        value: maxDepth,
        threshold: previousDepth,
      ),
    );
  }
  return issues;
}

/// Computes a repetitive series in order (issue #3565). Each dive after the
/// first starts from the dive before it: its tissues as they surfaced, after
/// the ascent and its stops, then off-gassed, and its CNS
/// decayed over the surface interval, the OTU of every dive that ended in
/// the last [otuCarryWindow], and each mapped tank at its source tank's end
/// pressure. The first dive starts from the logged dive it [follow]s, if
/// any, the same way; otherwise it is computed as given.
List<SeriesDiveResult> computeSeries(
  List<PlanSeriesDive> dives, {
  required PlanEngineConfig config,
  SeriesFollow? follow,
}) {
  final results = <SeriesDiveResult>[];
  for (var i = 0; i < dives.length; i++) {
    final state = carriedState(dives, i, results, follow: follow);
    final outcome = computeOutcomeForState(state, config: config);
    final issues = seriesIssuesFor(
      dives,
      i,
      state,
      outcome.maxDepth,
      results,
      config: config,
      follow: follow,
    );
    results.add(
      SeriesDiveResult(
        state: state,
        outcome: outcome.withIssues(issues),
        seriesIssues: issues,
      ),
    );
  }
  return results;
}

/// The inputs of the dive at [index] with what the dives before it carry in
/// applied, from [earlier]: the results of the dives before it, in order.
/// The first dive carries from the logged dive it [follow]s, if any.
///
/// The dive's start and surface interval are settled here too: a dive with
/// a [PlanSeriesDive.fixedStart] takes its interval from the time since the
/// previous dive ended, and any other takes its start from that end plus its
/// interval. With no previous end to measure from (no start before it), the
/// interval leads and the dive has no start.
DivePlanState carriedState(
  List<PlanSeriesDive> dives,
  int index,
  List<SeriesDiveResult> earlier, {
  SeriesFollow? follow,
}) {
  final dive = dives[index];
  if (index == 0 && follow == null) return dive.state;

  final timing = _timing(dive, previousEnd(index, earlier, follow: follow));
  final timed = dive.state.copyWith(
    surfaceInterval: timing.interval,
    startDateTime: timing.start,
    clearStartDateTime: timing.start == null,
  );
  final otu = _carriedOtu(index, timing.interval, earlier, follow);

  if (index == 0) {
    final tissues = follow!.endTissues;
    return timed.copyWith(
      initialTissueState: tissues,
      clearInitialTissueState: tissues == null,
      initialCns: follow.endCns,
      initialOtu: otu,
      tanks: followedTankPressures(
        dive.state.tanks,
        follow,
        sources: dive.sourceTankIds,
        pinned: dive.pinnedTankIds,
      ),
    );
  }
  final previous = earlier[index - 1];

  final remaining = {
    for (final usage in previous.outcome.tankUsages)
      if (usage.remainingPressure case final pressure?)
        usage.tankId: pressure < 0 ? 0.0 : pressure,
  };
  final before = {for (final tank in previous.state.tanks) tank.id: tank};
  final tanks = [
    for (final tank in dive.state.tanks)
      _carriedTank(
        tank,
        pinned: dive.pinnedTankIds.contains(tank.id),
        source: dive.sourceTankIds[tank.id],
        before: before,
        remaining: remaining,
      ),
  ];

  return timed.copyWith(
    initialTissueState: previous.outcome.surfacedTissue.compartments,
    initialCns: previous.outcome.cnsEnd,
    initialOtu: otu,
    tanks: tanks,
  );
}

/// [tank] as a later dive starts it. It carries what was left in its source
/// tank only while that is the same tank, the same size and gas. A linked
/// tank that is no longer the same one starts full, at its rated pressure. A
/// pinned tank, or one with no link, keeps the pressure it was given.
DiveTank _carriedTank(
  DiveTank tank, {
  required bool pinned,
  required String? source,
  required Map<String, DiveTank> before,
  required Map<String, double> remaining,
}) {
  if (pinned || source == null) return tank;
  final from = before[source];
  if (from != null && sameCylinder(from, tank)) {
    final left = remaining[source];
    return left == null ? tank : tank.copyWith(startPressure: left);
  }
  return tank.copyWith(
    startPressure: tank.workingPressure ?? tank.startPressure,
  );
}

/// When the dive before the one at [index] ended, as a true instant (see
/// `diveEndInstant`): the followed dive's end for the first dive, else the
/// previous dive's start plus its runtime. Null when the dive before has no
/// start, or a first dive follows none.
DateTime? previousEnd(
  int index,
  List<SeriesDiveResult> earlier, {
  SeriesFollow? follow,
}) {
  if (index == 0) return follow?.followed.endInstant;
  final previous = earlier[index - 1];
  final start = previous.state.startDateTime;
  if (start == null) return null;
  return fromWallClockUtc(
    start,
  ).add(Duration(seconds: previous.outcome.runtimeSeconds));
}

/// A dive's surface interval and start once settled against [previousEnd].
/// The start is clock digits stamped UTC, like the dive log's times; the
/// arithmetic runs on true instants so a daylight saving change in an
/// interval does not shift it by an hour.
({Duration interval, DateTime? start}) _timing(
  PlanSeriesDive dive,
  DateTime? previousEnd,
) {
  final own = dive.state.surfaceInterval ?? defaultSeriesSurfaceInterval;
  if (previousEnd == null) return (interval: own, start: null);
  final start = dive.state.startDateTime;
  if (dive.fixedStart && start != null) {
    final since = fromWallClockUtc(start).difference(previousEnd);
    // A start before the dive before it ends computes from no interval at
    // all; the series checks report it.
    return (interval: since.isNegative ? Duration.zero : since, start: start);
  }
  return (interval: own, start: asWallClockUtc(previousEnd.add(own)));
}

/// The OTU of every earlier dive, logged ones the series [follow]s
/// included, that ended less than [otuCarryWindow] before the dive at
/// [index] starts, [interval] after the one before it. Times run from the
/// first planned dive's start; each dive starts its surface interval after
/// the one before ends, as settled in [earlier].
double _carriedOtu(
  int index,
  Duration interval,
  List<SeriesDiveResult> earlier,
  SeriesFollow? follow,
) {
  final ends = <int>[];
  var clock = 0;
  for (var j = 0; j < index; j++) {
    if (j > 0) clock += _intervalSeconds(earlier[j].state);
    clock += earlier[j].outcome.runtimeSeconds;
    ends.add(clock);
  }
  final start = index == 0 ? 0 : clock + interval.inSeconds;

  var otu = 0.0;
  if (follow != null) {
    // The first planned dive starts its interval when the followed dive ends.
    final followedEnd = follow.followed.end;
    final firstStart = index == 0
        ? interval.inSeconds
        : _intervalSeconds(earlier[0].state);
    for (final logged in follow.loggedDives) {
      final sinceEnd =
          start + firstStart + followedEnd.difference(logged.end).inSeconds;
      if (sinceEnd < otuCarryWindow.inSeconds) otu += logged.otu;
    }
  }
  for (var j = 0; j < index; j++) {
    if (start - ends[j] >= otuCarryWindow.inSeconds) continue;
    final result = earlier[j];
    otu += result.outcome.otuTotal - (result.state.initialOtu ?? 0);
  }
  return otu;
}

int _intervalSeconds(DivePlanState state) =>
    (state.surfaceInterval ?? defaultSeriesSurfaceInterval).inSeconds;
