import 'package:submersion/features/agent_access/data/documents/dive_document.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';

/// The agent-facing document for a dive plan: its settings, then its tanks,
/// segments, gear and any scooter mission, which a plan always carries.
Map<String, Object?> divePlanDocument(DivePlan p) => {
  'id': p.id,
  'name': p.name,
  'notes': p.notes,
  'site_id': p.siteId,
  'mode': p.mode.name,
  'start_date_time': wallClockOrNull(p.startDateTime),
  'source_dive_id': p.sourceDiveId,
  'linked_dive_id': p.linkedDiveId,
  'altitude_m': p.altitude,
  'water_type': p.waterType?.name,
  'salinity_ppt': p.salinityPpt,
  'surface_interval_s': p.surfaceInterval?.inSeconds,
  'gf_low': p.gfLow,
  'gf_high': p.gfHigh,
  'descent_rate_m_min': p.descentRate,
  'ascent_rate_m_min': p.ascentRate,
  'intermediate_ascent_rate_m_min': p.intermediateAscentRate,
  'shallow_ascent_rate_m_min': p.shallowAscentRate,
  'final_ascent_rate_m_min': p.finalAscentRate,
  'last_stop_depth_m': p.lastStopDepth,
  'gas_switch_stop_s': p.gasSwitchStopSeconds,
  'stop_minimums_s': {
    for (final e in p.stopMinimums.entries) '${e.key}': e.value,
  },
  'sac_bottom_l_min': p.sacBottom,
  'sac_deco_l_min': p.sacDeco,
  'sac_stressed_l_min': p.sacStressed,
  'sac_factor': p.sacFactor,
  'reserve_pressure_bar': p.reservePressure,
  'problem_solving_minutes': p.problemSolvingMinutes,
  'ppo2_bottom_bar': p.ppO2Bottom,
  'ppo2_deco_bar': p.ppO2Deco,
  'ppo2_deco_band1_bar': p.ppO2DecoBand1,
  'ppo2_deco_band2_bar': p.ppO2DecoBand2,
  'ppo2_deco_band3_bar': p.ppO2DecoBand3,
  'max_o2_depth_m': p.maxO2DepthMeters,
  'hypercapnia_amv_l_min': p.hypercapniaAmv,
  'hypercapnia_minutes': p.hypercapniaMinutes,
  'best_mix_end_m': p.bestMixEndMeters,
  'o2_narcotic': p.o2Narcotic,
  'start_cns_percent': p.startCns,
  'start_otu': p.startOtu,
  'setpoint_low_bar': p.setpointLow,
  'setpoint_high_bar': p.setpointHigh,
  'setpoint_switch_depth_m': p.setpointSwitchDepth,
  'deviation_depth_delta_m': p.deviationDepthDelta,
  'deviation_time_minutes': p.deviationTimeMinutes,
  'turn_pressure_rule': p.turnPressureRule?.name,
  'turn_pressure_fraction': p.turnPressureFraction,
  'planned_weight_kg': p.plannedWeightKg,
  'planned_weight_placement_kg': p.plannedWeightPlacement,
  'equipment_ids': p.equipmentIds,
  'tanks': [for (final t in p.tanks) diveTankDocument(t)],
  'segments': [for (final s in p.segments) _segmentDocument(s)],
  'mission': p.mission == null ? null : _missionDocument(p.mission!),
};

Map<String, Object?> _segmentDocument(PlanSegment s) => {
  'id': s.id,
  'order': s.order,
  'target_depth_m': s.targetDepth,
  'duration_s': s.durationSeconds,
  'tank_id': s.tankId,
  'o2_fraction': s.gasMix.o2 / 100,
  'he_fraction': s.gasMix.he / 100,
  'setpoint_bar': s.setpointBar,
  'mode_override': s.diveModeOverride?.name,
  'split_at_configured_rate': s.splitAtConfiguredRate,
};

Map<String, Object?> _missionDocument(DpvMission m) => {
  'environment': m.environment.name,
  'battery_reserve_fraction': m.batteryReserveFraction,
  'walk_speed_m_s': m.walkSpeedMps,
  'surface_swim_limit_m': m.surfaceSwimLimitM,
  'legs': [
    for (final leg in m.legs)
      {
        'id': leg.id,
        'order': leg.order,
        'label': leg.label,
        'distance_m': leg.distanceM,
        'depth_m': leg.depthM,
        'heading_deg': leg.headingDeg,
      },
  ],
  'team': [
    for (final member in m.team)
      {
        'id': member.id,
        'order': member.order,
        'display_name': member.displayName,
        'buddy_id': member.buddyId,
        'diver_id': member.diverId,
        'sac_bottom_l_min': member.sacBottom,
        'swim_speed_m_s': member.swimSpeedMps,
      },
  ],
};
