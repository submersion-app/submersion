import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/domain/services/schedule_lines.dart';

/// One dive of a `compute_plan` answer (issue #4203): what the planner
/// shows for [result], metric and unit-named as every document is. [plan]
/// is the dive as computed, [config] the diver's settings it was computed
/// with, and [inputs] what it was computed from, in the shape a save takes.
Map<String, Object?> planResultDocument(
  SeriesDiveResult result, {
  required DivePlan plan,
  required PlanEngineConfig config,
  required Map<String, Object?> inputs,
}) {
  final outcome = result.outcome;
  // Tanks are named by place, as the inputs name them.
  final place = {for (final (i, t) in result.state.tanks.indexed) t.id: i};
  return {
    'schedule': [
      for (final line in scheduleLines(outcome.schedule)) _row(line, place),
    ],
    'stops': [
      for (final stop in outcome.stops)
        {
          'depth_m': stop.depthMeters,
          'duration_s': stop.durationSeconds,
          'air_break_s': stop.airBreakSeconds,
          'o2_fraction': _fraction(stop.gasFO2),
          'he_fraction': _fraction(stop.gasFHe),
          'tank': place[stop.tankId],
          'arrival_runtime_s': stop.arrivalRuntimeSeconds,
          'gas_switch_only': stop.isGasSwitchOnly,
        },
    ],
    'runtime_s': outcome.runtimeSeconds,
    'max_depth_m': outcome.maxDepth,
    // The engine writes -1 for a bottom already in deco; a client reads a
    // flag, not a sentinel.
    'ndl_at_bottom_s': outcome.ndlAtBottom < 0 ? null : outcome.ndlAtBottom,
    'in_deco_at_bottom': outcome.ndlAtBottom < 0,
    'tts_at_bottom_s': outcome.ttsAtBottom,
    'tank_usage': [
      for (final usage in outcome.tankUsages)
        {
          'tank': place[usage.tankId],
          'litres_used': _round(usage.litersUsed, 1),
          'start_pressure_bar': usage.startPressure,
          'remaining_pressure_bar': _maybeRound(usage.remainingPressure, 1),
          'percent_used': _round(usage.percentUsed, 1),
          'reserve_broken': usage.reserveViolation,
          'turn_pressure_bar': _maybeRound(usage.turnPressureBar, 1),
          'turn_pressure_missing': usage.turnPressureGap?.name,
          'min_gas_bar': _maybeRound(usage.minGasBar, 1),
          'min_gas_missing': usage.minGasGap?.name,
        },
    ],
    'cns_end_percent': _round(outcome.cnsEnd, 1),
    'otu_total': _round(outcome.otuTotal, 1),
    'issues': [for (final issue in outcome.issues) _issue(issue, place)],
    'carried_in': _carriedIn(result),
    'effective_settings': effectiveSettings(plan, config),
    'resolved_inputs': inputs,
  };
}

Map<String, Object?> _row(ScheduleLine line, Map<String, int> place) {
  final row = line.row;
  return {
    'kind': row.kind.name,
    'depth_m': row.depthMeters,
    'duration_s': row.durationSeconds,
    'runtime_s': row.runtimeSeconds,
    'duration_min': line.durationMinutes,
    'runtime_min': line.runtimeMinutes,
    'o2_fraction': _fraction(row.gasFO2),
    'he_fraction': _fraction(row.gasFHe),
    'tank': place[row.tankId],
    'gas_switch': row.gasSwitch,
    'air_break_s': row.airBreakSeconds,
    'ppo2_bar': _round(row.ppO2, 2),
    'end_m': _round(row.endMeters, 1),
    // Travel from the stop before, which has no row of its own: the row's
    // whole minutes cover it, its duration_s does not.
    if (row.kind == PlanScheduleRowKind.stop)
      'folded_travel': [
        for (final leg in row.foldedTravel)
          {
            'from_depth_m': leg.fromDepthMeters,
            'to_depth_m': leg.toDepthMeters,
            'duration_s': leg.seconds,
            'tank': place[leg.tankId],
          },
      ],
  };
}

Map<String, Object?> _issue(PlanIssue issue, Map<String, int> place) => {
  'type': issue.type.name,
  'severity': issue.severity.name,
  'message': issue.message,
  'at_runtime_s': issue.atRuntime,
  'at_depth_m': issue.atDepth,
  'tank': place[issue.tankId],
  'value': issue.value,
  'threshold': issue.threshold,
};

/// What a dive started with from the dives before it, or null for a dive
/// that started fresh.
Map<String, Object?>? _carriedIn(SeriesDiveResult result) {
  final state = result.state;
  final tissues = state.initialTissueState != null;
  final cns = state.initialCns ?? 0;
  final otu = state.initialOtu ?? 0;
  if (!tissues && cns == 0 && otu == 0 && state.surfaceInterval == null) {
    return null;
  }
  return {
    'start_date_time': state.startDateTime == null
        ? null
        : wallClock(asWallClockUtc(state.startDateTime!)),
    'surface_interval_s': state.surfaceInterval?.inSeconds,
    'tissues_loaded': tissues,
    'cns_percent': _round(cns, 1),
    'otu': _round(otu, 1),
  };
}

/// Each setting [plan] was computed with, by the key a plan sets it with
/// where it can: its value, and whether it came from the plan, the
/// diver's Settings ([config]), or the planner's default.
Map<String, Object?> effectiveSettings(DivePlan plan, PlanEngineConfig config) {
  Map<String, Object?> own(Object? planValue, Object settingsValue) => {
    'value': planValue ?? settingsValue,
    'source': planValue == null ? 'settings' : 'plan',
  };
  Map<String, Object?> fromSettings(Object? value) => {
    'value': value,
    'source': 'settings',
  };
  return {
    'gf_low': own(plan.gfLow, config.gfLow),
    'gf_high': own(plan.gfHigh, config.gfHigh),
    'descent_rate_m_min': own(plan.descentRate, config.descentRate),
    'ascent_rate_m_min': own(plan.ascentRate, config.ascentRate),
    'intermediate_ascent_rate_m_min': own(
      plan.intermediateAscentRate,
      config.intermediateAscentRate,
    ),
    'shallow_ascent_rate_m_min': own(
      plan.shallowAscentRate,
      config.shallowAscentRate,
    ),
    'final_ascent_rate_m_min': own(
      plan.finalAscentRate,
      config.finalAscentRate,
    ),
    'last_stop_depth_m': own(plan.lastStopDepth, config.lastStopDepth),
    'gas_switch_stop_s': own(
      plan.gasSwitchStopSeconds,
      config.gasSwitchStopSeconds,
    ),
    'sac_bottom_l_min': own(plan.sacBottom, config.sacBottom),
    'sac_deco_l_min': own(plan.sacDeco, config.sacDeco),
    // The problem-solving allowance: problem_solving_minutes at the deepest
    // point on bottom SAC x sac_factor, included in litres_used.
    'sac_factor': own(plan.sacFactor, config.buddyFactor),
    'problem_solving_minutes': own(
      plan.problemSolvingMinutes,
      config.problemSolvingMinutes,
    ),
    'reserve_pressure_bar': own(plan.reservePressure, config.reservePressure),
    'ppo2_bottom_bar': own(plan.ppO2Bottom, config.ppO2Working),
    'ppo2_deco_bar': own(plan.ppO2Deco, config.ppO2Deco),
    'o2_narcotic': own(plan.o2Narcotic, config.o2Narcotic),
    'end_limit_m': fromSettings(config.endLimitMeters),
    'cns_warning_percent': fromSettings(config.cnsWarningThreshold),
    'gas_model': fromSettings(config.gasModel.name),
    'cns_method': fromSettings(config.cnsMethod.name),
    'water_type': {
      'value': (plan.waterType?.name) ?? 'salt',
      'source': plan.waterType == null ? 'default' : 'plan',
    },
    'altitude_m': {
      'value': plan.altitude ?? 0,
      'source': plan.altitude == null ? 'default' : 'plan',
    },
  };
}

/// A gas fraction to four places.
double _fraction(double fraction) => _round(fraction, 4);

double _round(double value, int places) =>
    double.parse(value.toStringAsFixed(places));

double? _maybeRound(double? value, int places) =>
    value == null ? null : _round(value, places);
