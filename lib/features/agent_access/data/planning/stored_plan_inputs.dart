import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_fields.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';

/// A saved plan's own value of each setting `compute_plan` takes, by input
/// key; null for one it leaves to the diver's Settings. Every key of
/// [planSettingFields] has an entry, which a test holds to.
Map<String, Object?> planSettingValues(DivePlan p) => {
  'water_type': p.waterType?.name,
  'gf_low': p.gfLow,
  'gf_high': p.gfHigh,
  'altitude_m': p.altitude,
  'salinity_ppt': p.salinityPpt,
  'descent_rate_m_min': p.descentRate,
  'ascent_rate_m_min': p.ascentRate,
  'intermediate_ascent_rate_m_min': p.intermediateAscentRate,
  'shallow_ascent_rate_m_min': p.shallowAscentRate,
  'final_ascent_rate_m_min': p.finalAscentRate,
  'last_stop_depth_m': p.lastStopDepth,
  'sac_bottom_l_min': p.sacBottom,
  'sac_deco_l_min': p.sacDeco,
  'sac_factor': p.sacFactor,
  'reserve_pressure_bar': p.reservePressure,
  'ppo2_bottom_bar': p.ppO2Bottom,
  'ppo2_deco_bar': p.ppO2Deco,
  'gas_switch_stop_s': p.gasSwitchStopSeconds,
  'problem_solving_minutes': p.problemSolvingMinutes,
  'o2_narcotic': p.o2Narcotic,
};

/// A saved plan as `compute_plan` takes a dive (issue #4203): its mode, its
/// own settings, tanks and segments, and its start when [withStart]. What
/// it leaves to Settings is left out, as `resolved_inputs` leaves it out
/// for a plan an agent describes, so the same map computes it again.
Map<String, Object?> planInputsOf(DivePlan p, {required bool withStart}) {
  final tankPlace = {for (final (i, t) in p.tanks.indexed) t.id: i};
  return {
    'mode': p.mode.name,
    if (withStart && p.startDateTime != null)
      'start_date_time': planComputeFields['start_date_time']!.wire(
        asWallClockUtc(p.startDateTime!),
      ),
    for (final MapEntry(:key, :value) in planSettingValues(p).entries)
      key: ?value,
    'tanks': [for (final t in p.tanks) _tank(t)],
    'segments': [
      for (final s in p.segments)
        {
          'target_depth_m': s.targetDepth,
          'duration_s': s.durationSeconds,
          // A segment always breathes one of its plan's tanks.
          'tank': tankPlace[s.tankId] ?? 0,
          'setpoint_bar': s.setpointBar,
          'split_at_configured_rate': s.splitAtConfiguredRate,
        },
    ],
  };
}

Map<String, Object?> _tank(DiveTank t) => {
  'name': t.name,
  'volume_l': t.volume,
  'working_pressure_bar': t.workingPressure,
  'start_pressure_bar': t.startPressure,
  'o2_fraction': t.gasMix.o2 / 100,
  'he_fraction': t.gasMix.he / 100,
  'role': t.role.name,
  'deco_switch_depth_m': t.decoSwitchDepth,
};

/// Each dive of a saved series as `compute_plan` takes it, in order:
/// [planInputsOf], with how it is timed and where its tanks carry from.
/// [follow] is the logged dive it follows, as the series was computed with,
/// whose tanks the first dive's carry from.
List<Map<String, Object?>> seriesInputsOf(
  StoredSeries s, {
  required SeriesFollow? follow,
}) {
  final logged = [...?follow?.endTanks]
    ..sort((a, b) => a.order.compareTo(b.order));
  return [
    for (final (i, dive) in s.dives.indexed)
      _seriesDive(
        dive,
        before: i == 0
            ? (follow == null ? null : logged)
            : s.dives[i - 1].plan.tanks,
        first: i == 0,
      ),
  ];
}

Map<String, Object?> _seriesDive(
  StoredSeriesDive dive, {
  required List<DiveTank>? before,
  required bool first,
}) {
  final plan = dive.plan;
  // A dive that carries in, a later one or a first one after a followed
  // dive, is timed by its interval unless it holds its own start; the
  // parser takes one or the other, never both.
  final carriesIn = !first || before != null;
  final byInterval = carriesIn && !dive.fixedStart;
  final interval = byInterval ? plan.surfaceInterval?.inSeconds : null;
  final beforePlace = {
    for (final (i, t) in (before ?? const <DiveTank>[]).indexed) t.id: i,
  };
  return {
    ...planInputsOf(plan, withStart: !byInterval),
    'surface_interval_s': ?interval,
    if (before != null)
      'carries_from_tank': [
        for (final t in plan.tanks) beforePlace[dive.sourceTankIds[t.id]],
      ],
  };
}
