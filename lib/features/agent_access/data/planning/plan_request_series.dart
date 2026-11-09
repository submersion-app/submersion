import 'package:uuid/uuid.dart';

import 'package:submersion/features/agent_access/data/planning/plan_request.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_fields.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/logged_dive_chain.dart';

const _uuid = Uuid();

/// [request] as a saved series would hold it, never saved: each dive's
/// plan, where its tanks carry from, and how it is timed, so it computes
/// through the same path a saved series opens by (issue #4203). [follow]
/// is the logged dive it follows as that dive is now, read by the caller.
///
/// Also returns each dive's inputs with what the planner chose for it
/// written in: which tank each carries from, and a first dive's interval
/// after the dive it follows.
({StoredSeries stored, List<Map<String, Object?>> inputs}) storedSeriesFor(
  PlanRequest request, {
  required SeriesFollow? follow,
  required DateTime now,
  String Function()? newId,
}) {
  final id = newId ?? _uuid.v4;
  final logged = [...?follow?.endTanks]
    ..sort((a, b) => a.order.compareTo(b.order));
  final dives = <StoredSeriesDive>[];
  final inputs = <Map<String, Object?>>[];
  for (final (index, dive) in request.dives.indexed) {
    final previous = dives.lastOrNull?.plan.tanks;
    final before = previous ?? (follow == null ? null : logged);
    var interval = dive.surfaceInterval;
    if (index == 0 && follow != null && interval == null && !dive.fixedStart) {
      interval = followSurfaceInterval(follow.followed.endInstant, now: now);
    }
    final plan = applyPlanValues(
      DivePlan(id: id(), name: '', createdAt: now, updatedAt: now),
      dive.values,
      newId: id,
    ).copyWith(surfaceInterval: interval);
    final carries = before == null
        ? null
        : dive.carriesFromTank ??
              _matched(plan.tanks, before, byPlace: !dive.tanksGiven);
    if (carries != null) {
      for (final from in carries) {
        if (from != null && from >= before!.length) {
          throw AgentToolException(
            AgentToolErrorCode.invalidArgument,
            'carries_from_tank: $from is not a tank of the '
            '${previous == null ? 'followed dive' : 'dive before'}, which '
            'has ${before.length}.',
            details: {'field': 'dives[$index].carries_from_tank'},
          );
        }
      }
    }
    dives.add(
      StoredSeriesDive(
        plan: plan,
        fixedStart: dive.fixedStart,
        sourceTankIds: {
          if (carries != null)
            for (final (i, from) in carries.indexed)
              if (from != null) plan.tanks[i].id: before![from].id,
        },
      ),
    );
    inputs.add({
      ...dive.inputs,
      'surface_interval_s': ?interval?.inSeconds,
      'carries_from_tank': ?carries,
    });
  }
  return (
    stored: StoredSeries(
      id: id(),
      name: '',
      followedDiveId: request.followDiveId,
      dives: dives,
    ),
    inputs: inputs,
  );
}

/// Which of [before] each of [tanks] carries from: the tank at the same
/// place when the dive took the tanks before [byPlace], as a dive the
/// planner adds does; otherwise the first not yet taken of the same size
/// and gas, a dive before or a logged dive alike.
List<int?> _matched(
  List<DiveTank> tanks,
  List<DiveTank> before, {
  required bool byPlace,
}) {
  if (byPlace) {
    return [
      for (var i = 0; i < tanks.length; i++) i < before.length ? i : null,
    ];
  }
  final taken = <int>{};
  return [
    for (final tank in tanks)
      () {
        for (final (i, other) in before.indexed) {
          if (!taken.contains(i) && _same(tank, other)) {
            taken.add(i);
            return i;
          }
        }
        return null;
      }(),
  ];
}

/// A logged tank keeps no working pressure the plan states, so a plan tank
/// matches one of the same size and gas.
bool _same(DiveTank a, DiveTank b) =>
    a.volume == b.volume &&
    a.gasMix.roundedO2 == b.gasMix.roundedO2 &&
    a.gasMix.roundedHe == b.gasMix.roundedHe;
