import 'package:submersion/features/agent_access/data/documents/plan_documents.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request_series.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_fields.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';

/// A saved plan's own value of each setting `compute_plan` takes, by input
/// key; null for one it leaves to the diver's Settings. Read from the
/// plan's `dive_plans` document, which holds every key of
/// [planSettingFields], so the two never disagree.
Map<String, Object?> planSettingValues(DivePlan p) =>
    _settingsOf(_documentOf(p));

Map<String, Object?> _documentOf(DivePlan p) =>
    divePlanDocument(p, logged: const {});

Map<String, Object?> _settingsOf(Map<String, Object?> document) {
  assert(
    planSettingFields.keys.every(document.containsKey),
    'divePlanDocument must hold every plan setting compute_plan takes.',
  );
  return {for (final key in planSettingFields.keys) key: document[key]};
}

/// A saved plan as `compute_plan` takes a dive (issue #4203): its mode, its
/// own settings, tanks and segments, and its start when [withStart]. What
/// it leaves to Settings is left out, as `resolved_inputs` leaves it out
/// for a plan an agent describes, so the same map computes it again.
Map<String, Object?> planInputsOf(DivePlan p, {required bool withStart}) {
  final document = _documentOf(p);
  return {
    'mode': document['mode'],
    if (withStart) 'start_date_time': ?document['start_date_time'],
    for (final MapEntry(:key, :value) in _settingsOf(document).entries)
      key: ?value,
    ...planPartsAsWritten(document),
  };
}

/// Each dive of a saved series as `compute_plan` takes it, in order:
/// [planInputsOf], with how it is timed and where its tanks carry from.
/// [follow] is the logged dive it follows, as the series was computed with,
/// whose tanks the first dive's carry from.
List<Map<String, Object?>> seriesInputsOf(
  StoredSeries s, {
  required SeriesFollow? follow,
}) {
  final logged = followedTanksInOrder(follow);
  // A series has a clock only when it follows a logged dive or its first
  // dive has a start; without one, the planner times a later dive by its
  // interval whatever start it holds, and the parser refuses that start.
  final timed = follow != null || s.dives.first.plan.startDateTime != null;
  return [
    for (final (i, dive) in s.dives.indexed)
      _seriesDive(
        dive,
        before: i == 0
            ? (follow == null ? null : logged)
            : s.dives[i - 1].plan.tanks,
        first: i == 0,
        timed: timed,
        previous: i == 0 ? null : s.dives[i - 1].plan,
      ),
  ];
}

Map<String, Object?> _seriesDive(
  StoredSeriesDive dive, {
  required List<DiveTank>? before,
  required bool first,
  required bool timed,
  required DivePlan? previous,
}) {
  final plan = dive.plan;
  // The parser gives a later dive the dive before's value of any setting
  // it leaves out, while the planner computes it with its own, null
  // meaning Settings. So a setting this dive leaves unset where the dive
  // before sets one is written as null.
  final own = planSettingValues(plan);
  final cleared = [
    if (previous != null)
      for (final MapEntry(:key, :value) in planSettingValues(previous).entries)
        if (value != null && own[key] == null) key,
  ];
  // A dive that carries in, a later one or a first one after a followed
  // dive, starts at its own start only when it holds one fixed on a series
  // with a clock. Otherwise it is timed by its interval, the planner's
  // default when it stores none, as the series calculator times it. The
  // parser takes one or the other, never both.
  final carriesIn = !first || before != null;
  final ownStart = dive.fixedStart && plan.startDateTime != null && timed;
  final byInterval = carriesIn && !ownStart;
  final interval = byInterval
      ? (plan.surfaceInterval ?? defaultSeriesSurfaceInterval).inSeconds
      : null;
  final beforePlace = {
    for (final (i, t) in (before ?? const <DiveTank>[]).indexed) t.id: i,
  };
  return {
    ...planInputsOf(plan, withStart: !byInterval),
    for (final key in cleared) key: null,
    'surface_interval_s': ?interval,
    if (before != null)
      'carries_from_tank': [
        // A pinned tank keeps the pressure it was given, as a tank that
        // carries from none does.
        for (final t in plan.tanks)
          dive.pinnedTankIds.contains(t.id)
              ? null
              : beforePlace[dive.sourceTankIds[t.id]],
      ],
  };
}
